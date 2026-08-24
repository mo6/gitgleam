# Security Policy

## Supported versions

Only the latest release (tagged on `main`) is supported. Please update to the
latest version before reporting an issue.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for a security vulnerability.

Instead, report it privately via
[GitHub Security Advisories](https://github.com/mo6/gitgleam/security/advisories/new),
or by emailing gmo6nl@gmail.com.

Include what you'd include in any bug report: steps to reproduce, the
version/commit affected, and the potential impact. You should get a response
within a few days.

## Scope notes

Gitgleam is a local, unsandboxed macOS menu bar app that shells out to
`/usr/bin/git` and (optionally) a user-configured `viewmd.sh` script against a
repository path you point it at. Markdown **Web** preview also renders that
file's HTML in a `WKWebView` with JavaScript enabled for the bundled marked
and mermaid copies. It does not run as a service, accept network input, or
transmit data anywhere. Reports involving arbitrary code execution via a
specially crafted repository (e.g. through git output, commit metadata, or
Markdown/Mermaid content rendered in previews) are in scope.

## Security measures

### Development

- **No Swift package dependencies.** The package has zero external Swift
  dependencies. The Markdown **Web** preview vendors two JavaScript libraries
  (`marked`, `mermaid`) in `Sources/Gitgleam/WebPreview/` and loads them from
  the app bundle over `file://` — no CDN, no runtime network. They are not
  resolved through SwiftPM. The same versions are pinned in
  `scripts/webpreview/package.json` so npm audit and Dependabot can see them
  (see *Vendored Web preview dependencies* below).
- **Swift 6 strict concurrency** is enabled throughout, so UI state can only
  be mutated on the main actor, eliminating a class of data races between the
  filesystem watcher, the periodic poll, and user-triggered refreshes.
- **Absolute paths for every subprocess**, never a bare command name. Both
  `Git.run` (`/usr/bin/git`) and `Viewmd.render` (`/bin/bash`) hardcode the
  executable path so a GUI app's empty/attacker-influenced `PATH` cannot
  redirect execution to a different binary.
- **Arguments are passed as an array**, not interpolated into a shell string,
  for every `git` invocation — so a file or branch name containing shell
  metacharacters cannot break out of the intended argument.
- **`viewmd.sh` input goes through a real file, not shell interpolation.**
  Markdown content is written to a fresh, randomly-named temp file
  (`FileManager.temporaryDirectory` + `UUID`) and passed to `bash` as a
  positional argument; it is never substituted into a command string, and the
  temp file is removed after rendering.
- **A locked-down render environment.** `viewmd` is invoked with
  `VIEWMD_NO_CONFIG=1` and explicit `--color`/`--no-toc`/`--width` flags, so a
  user's own `viewmd` config file cannot silently change what gets executed
  or rendered.
- **ANSI output is parsed, not interpreted.** `ANSIText` only recognizes SGR
  color/style escapes and strips OSC 8 hyperlink sequences down to their
  label text; it does not act on other OSC/DCS sequences that a malicious
  file (via `viewmd`) could try to smuggle through the pipe.
- **Web preview stays on the bundled page.** `WKWebView` loads `preview.html`
  from the resource bundle (`loadFileURL` + read access only to that folder).
  In-page navigation is cancelled except that `file://` load; `http(s)` links
  are handed to the system browser. Mermaid runs with `securityLevel: strict`.
  A light sanitizer in `preview.js` strips `script`/`iframe`/`object`/`embed`,
  `link[href]`, `meta`, `on*` handlers, and `javascript:` URLs from marked's
  HTML; it is not a complete HTML sanitizer. YAML front matter is parsed in
  JS (not passed through marked as raw `---`) and rendered as a Field/Value
  table with `textContent`.
- **No App Sandbox entitlements are requested**, which is a deliberate
  trade-off for an unbundled SPM binary rather than a hidden default — see
  the *Scope notes* above.

### Vendored Web preview dependencies

The copies Gitgleam actually loads are the minified files in
`Sources/Gitgleam/WebPreview/` (`marked.min.js`, `mermaid.min.js`), with
human-readable versions in `NOTICE.txt`. Those files are not an npm project,
so GitHub's dependency graph would otherwise never see them.

To make security updates visible, the **same exact versions** are declared as
npm dependencies in a lockfile that is never installed into the app:

| File | Role |
| --- | --- |
| `scripts/webpreview/package.json` | Exact pins (`marked`, `mermaid`). Source of truth for bumps. |
| `scripts/webpreview/package-lock.json` | Lockfile `npm audit` and Dependabot read. |
| `Sources/Gitgleam/WebPreview/NOTICE.txt` | Same pins, plus MIT attribution (ships in the bundle). |
| `THIRD_PARTY_NOTICES.md` | Repo-root index of those licenses (GitHub / source checkout). |
| `Sources/Gitgleam/WebPreview/*.min.js` | Runtime copies loaded by `WKWebView`. |

Current pins: **marked 15.0.12**, **mermaid 11.17.1**.

**CI** (`.github/workflows/ci.yml`, job `webpreview-deps`) runs
`scripts/check-webpreview-deps.sh` on every push to `develop`/`main`, every
pull request, and weekly (`cron: 17 4 * * 1`). The script:

1. Fails if `NOTICE.txt`, `package.json`, and the vendored JS disagree.
2. Runs `npm audit --package-lock-only --audit-level=moderate` (no
   `node_modules` in the app; moderate and higher advisories fail the job).

**Dependabot** (`.github/dependabot.yml`) watches `package-ecosystem: npm` in
`/scripts/webpreview` on a weekly schedule. Its PRs bump the pin and lockfile
only. After merging (or before, on the PR branch):

```bash
scripts/vendor-webpreview.sh          # re-download min.js + LICENSE + NOTICE + THIRD_PARTY_NOTICES.md
scripts/check-webpreview-deps.sh      # confirm lockstep + clean audit
```

`scripts/webpreview/` is audit metadata only. Do not `npm install` those
packages into Gitgleam; the binary must keep using the vendored files.

### Testing

- **Unit tests target the string/byte-parsing logic that handles untrusted
  input** (`Tests/GitgleamTests`, run via `swift test`): `ANSIText` is tested
  against malformed and truncated SGR/OSC escape sequences (not just
  well-formed ones), `MarkdownHighlighter` is tested against diffs with
  fenced code blocks and partial/whole-block changes, and `AppConfig` is
  tested for flag-parsing and threshold-clamping edge cases.
- **`WebPreviewDependencyTests`** (`swift test`) checks that `NOTICE.txt`,
  `scripts/webpreview/package.json`, the `marked.min.js` header, and the
  version string inside `mermaid.min.js` stay in lockstep. It does not call
  the npm registry; `scripts/check-webpreview-deps.sh` does that (locally
  when node is available, and in CI).
- **Every change is verified with a debug build, a release build, and the
  full test suite** before being committed (see `AGENTS.md`), so a
  regression in argument handling or parsing is caught before it ships.
