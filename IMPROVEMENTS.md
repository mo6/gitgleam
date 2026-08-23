# Improvements

Ideas for Gitgleam that fit the current app: a small native menu-bar watcher
with a colored diff, not a second Git GUI. Items are grouped by theme, not
priority. `FileKind.swift` already calls Markdown preview "stage 1" of
file-type-dependent rendering — that is the main architectural next step.

Existing one-liners in `AGENTS.md` (Finder, editor, syntax highlighting,
`.app` bundle) are expanded here rather than duplicated as stubs.

---

## File-type viewers (configurable)

Today preview is one special case: if the path looks like Markdown
(`FileKind.isMarkdown`) and Settings has a `viewmd` launcher, `DiffView` /
`CommitFilePane` show a Diff/Preview toggle and shell out to `Viewmd.render`.
Everything else is the colored unified diff. `ViewMode` is only `diff` |
`preview`.

A better model is a **list of viewer rules** in Settings, keyed by file type,
with the existing Markdown/viewmd pair as the first built-in row.

### Rule shape

Each rule would be something like:

- **Match** — extensions (and later UTIs), e.g. `md, markdown, mdown`.
- **Viewer** — a built-in, or a user-supplied command.
- **How to run it** — placeholders such as `{file}`, `{width}`, `{theme}`;
  stdin vs a temp file (viewmd already uses a temp `.md`).
- **Output** — ANSI (reuse `ANSIText` + `MonospacedTextScroll`), plain text,
  or an image. HTML/`WKWebView` only if a built-in actually needs it.
- **Default mode** — open in preview or in the diff (today's
  `--default-view`, but per type).
- **Enabled** — so a rule can be kept without being used.

Unmatched files stay diff-only. A viewer failure already falls back to the
diff for Markdown; that should stay the rule for every type.

### Built-ins worth shipping

These reuse windows and toggles that already exist; they do not need a new
surface per type.

| Kind | Why |
| --- | --- |
| **Markdown / viewmd** | Current behavior, just one row in the table. |
| **Images** (`png`, `jpg`, `gif`, `webp`, `heic`, `svg`) | A unified diff of binary/XML is useless. Show the working-tree image; later, working tree vs `HEAD` side by side. |
| **JSON / YAML** | Pretty-print (and maybe a structural diff) instead of a wall of `+/-`. |
| **Source** | Optional external colorizer (`bat`, `pygmentize`) producing ANSI, until an in-process highlighter exists. |
| **Binary / unknown** | Size and a short message, not a garbled "diff". |

Custom rows cover the rest: `.typ` → typst, `.ipynb` → nbconvert, `.csv` →
something table-like, or "Open with Preview.app" as an *external* viewer
rather than an in-window pane.

### How it fits the code

- Generalize `FileKind` into matchers + a small registry. `isMarkdown` becomes
  one matcher, not the only branch in `DiffView`.
- `Viewmd` becomes one `Viewer` implementation (ANSI from a `Process`). Image
  preview is another (read the file, `NSImage`). Custom commands share the
  same temp-file + drain-stdout pattern `Git` / `Viewmd` already use.
- Settings today stores a single `viewmdPath` / `defaultView` /
  `previewWidth`. Those migrate into the Markdown rule so existing
  `UserDefaults` blobs keep working (`StoredSettings` optional-field pattern).
- Keep commands as argument arrays, never a shell string — same trust model
  as `/usr/bin/git` and `/bin/bash` + `viewmd.sh`.

A first cut can be: built-in Markdown + Images + Binary, plus one "custom
command" row type. Syntax-highlighted source and JSON pretty-print can follow
without changing the Settings shape.

---

## Diff quality

The diff is a single monospaced `AttributedString` with green/red lines. That
is enough for Markdown notes; it is thin for code.

- **Syntax highlighting inside the diff** (already in the backlog) — color
  the line *contents*, keep +/- as the status color. Harder than a full-file
  highlighter because each line is a fragment.
- **Word-level** highlighting on changed lines, so a one-word edit in a long
  paragraph is visible.
- **Jump to first change** — full-context diffs (`-U1000000`) open at the
  top of the file.
- **Wrap vs horizontal scroll** as a setting; wrapping helps prose, scrolling
  helps code.
- **Deleted files** are non-clickable text in the menu and in
  `AllChangesView`. Opening them should show `git show HEAD:path` (and
  preview, if a viewer matches).
- **Rename** — porcelain is parsed to the new path only (`FileChange`).
  Showing old → new in the menu row, and a rename-aware diff, would match
  what git actually did.

---

## Menu and file actions

The dropdown is view-only. A few actions would make it a hub without turning
it into a porcelain frontend.

- **Reveal in Finder** / **copy path** / **open in editor** (backlog) —
  editor from a Settings path or `NSWorkspace`. Secondary-click on a file
  row, or a small "…" in the diff header, beats crowding the menu with four
  buttons per file.
- **Open the repo** in Terminal or the editor, from the repo submenu.
- **Filter** in `AllChangesView` when a vault dumps 80 files.
- **Branch name** (and ahead/behind, if cheap) in the repo submenu title,
  next to the count.
- **Staged vs unstaged** — porcelain already has XY codes; the menu could
  split or badge them. Only worth it if people using Gitgleam actually stage.
- **Notifications** when the aggregate count crosses the critical threshold,
  off by default.

---

## Multi-repo and Settings

Multi-repo is new; the Settings surface is still global.

- ~~**Drag to reorder** repos (display order is already `settings.repos`
  order).~~
- ~~**Disable without deleting** — keep path/label, skip the watcher.~~
- ~~**Warn on duplicate paths** and on a folder that is not a git repo
  (the orange triangle exists; blocking Add, or offering "initialize", would
  go further).~~
- ~~**Per-repo overrides** only where it hurts that they are global: warn/
  critical thresholds, maybe which viewer rules apply (a notes vault vs a
  code repo). Everything else can stay shared.~~
- ~~**Export / import** the JSON blob. It already lives as JSON under
  `nl.mo6.gitgleam.settings` in `~/Library/Preferences/Gitgleam.plist`; a
  file on disk is easier to back up and to inspect than `defaults`.~~
- ~~**Cap or warn** on a huge repo list (each entry is a timer + FSEvents +
  `git status`). Self-inflicted, but easy to do by accident with "Add".~~

**Implemented (2026-08-23).** Settings → Repositories now supports drag-to-reorder
(grip on each row), a checkbox to pause a repo without deleting it (no
FSEvents watcher or `git status` until it's on again; the menu shows it as
paused), duplicate-path and not-a-git-repo alerts on Add/Choose (Initialize
Git / Add anyway / Cancel), per-repo warn/critical overrides (or "App
defaults"), Export…/Import… of the same JSON blob `UserDefaults` stores
(`gitgleam-settings.json`), a warning from 8 repos and a hard cap at 20.
Paused repos do not contribute to the aggregate menu-bar count.

Per-repo *viewer-rule* overrides are not in this pass — they wait on the
file-type viewer table above. Everything else in this section still uses the
global Settings values.

---

## Git workflow (keep it small)

A full commit UI is out of character. Two narrow actions would still help
a notes vault:

- **Discard this file** (`git checkout --` / `git restore`, with a
  confirmation) from the diff window.
- **Open a pre-filled commit** in Terminal or `$EDITOR`, rather than
  implementing staging, message, and amend in-process.

Remote pull/push, stash, and branch switching belong in a Git client.

---

## App packaging

Still a raw SPM executable + LaunchAgent.

- **Real `.app` bundle** (backlog) so Login Items work and the binary +
  `Gitgleam_Gitgleam.bundle` stay together. `LSUIElement` / accessory policy
  already exists in the `AppDelegate`. Multiple instances used to be a
  feature; one process now watches every repo, so
  `LSMultipleInstancesProhibited` is acceptable.
- **Sparkle** (or similar) only after it is a bundle; until then "rebuild
  the LaunchAgent binary" is the update story.

---

## Smaller polish

- Font size for diff/preview, independent of system size.
- Remember the last Diff/Preview choice per file kind (not only the default).
- Clicking a conflict (`UU` / `AA` / `DD`) could say so more loudly than
  `statusDescription`.
- `AllChangesView` could take a search field and keep deleted files
  clickable (see above).

None of this needs to land together. The viewer-rule table is the change
that unlocks images, binaries, and custom tools without another
Markdown-shaped special case.
