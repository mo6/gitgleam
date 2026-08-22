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
repository path you point it at. It does not run as a service, accept network
input, or transmit data anywhere. Reports involving arbitrary code execution
via a specially crafted repository (e.g. through git output, commit
metadata, or Markdown/Mermaid content rendered in previews) are in scope.

## Security measures

### Development

- **No third-party dependencies.** The package has zero external
  dependencies, so there is no supply-chain surface from transitive packages.
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
- **No App Sandbox entitlements are requested**, which is a deliberate
  trade-off for an unbundled SPM binary rather than a hidden default — see
  the *Scope notes* above.

### Testing

- **Unit tests target the string/byte-parsing logic that handles untrusted
  input** (`Tests/GitgleamTests`, run via `swift test`): `ANSIText` is tested
  against malformed and truncated SGR/OSC escape sequences (not just
  well-formed ones), `MarkdownHighlighter` is tested against diffs with
  fenced code blocks and partial/whole-block changes, and `AppConfig` is
  tested for flag-parsing and threshold-clamping edge cases.
- **Every change is verified with a debug build, a release build, and the
  full test suite** before being committed (see `AGENTS.md`), so a
  regression in argument handling or parsing is caught before it ships.
