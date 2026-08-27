# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.7.0] - 2026-08-27

### Added

- **German, French, and Spanish translations** (`de`, `fr`, `es`), alongside
  the existing English and Dutch ones. Each appears as a choice in
  Settings → General → Language.
- **Simplified and Traditional Chinese translations** (`zh-hans`, `zh-hant`).

### Changed

- **Diff and Diff (full) now wrap long lines and show old/new line-number
  gutters**, instead of requiring horizontal scrolling. Each line is its own
  row with a two-column gutter (old file line # | new file line #, parsed
  from each hunk's `@@ -l,s +l,s @@` header); added lines show only their new
  line number, removed lines only their old one, context lines show both.
- **Added/removed diff lines are now marked with a full-width background
  tint** (translucent green/red, theme-aware for light and dark) instead of
  colored +/- text, matching the diff style used by editors like Claude
  Code/VS Code.
- **Word-level inline highlighting** for a replaced line: when a removed
  line is immediately followed by an added line (git's usual layout for a
  one-line edit), the specific words that changed get a stronger background
  tint on top of the row's tint, so a small edit inside a long line stands
  out instead of requiring a read of the whole line.
- **Wrap lines** setting (Settings → Diff), on by default: turn it off to
  keep Diff/Diff (full) lines on one row and scroll horizontally instead of
  wrapping them.
- **A brand-new, entirely untracked folder now lists its files individually**
  instead of collapsing to one unopenable "folder" row: `git status` runs
  with `--untracked-files=all`, so every file inside (recursively, still
  respecting `.gitignore`) gets its own sidebar row, change count, and diff
  — same as any other new file.

### Removed

- **The `--warn`, `--critical`, `--interval`, `--commits`, `--default-view`,
  and `--preview-width` CLI flags.** Everything they set is fully
  configurable live from Settings, so a CLI flag is no longer the only way
  to change them; they now always start at a fixed default (unchanged:
  warn 1, critical 10, interval 60s, commits 10, default view Preview,
  preview width 100) instead of that default being overridable at launch. If
  a LaunchAgent plist passes any of these, remove them — an unrecognized
  flag is silently ignored, but the value it used to set now has to be
  entered in Settings instead. `--repo`/`--path`/`--label` and
  `--viewmd-path` are unaffected (still useful to pre-seed a fresh install,
  e.g. from a LaunchAgent).

## [1.6.0] - 2026-08-26

### Added

- **Diff (full)** toggle alongside **Diff** on every file pane (uncommitted
  or commit), not just Markdown ones. **Diff** now shows a concise diff at
  git's default context (a few lines around each change); **Diff (full)**
  shows the whole file with the +/- lines colored in place — the app's
  previous, only behavior. The **Default view** setting that picks between
  them (plus Preview/Web for Markdown) moves out of Settings → Markdown
  preview into a new Settings → **Diff** section, since it's no longer
  Markdown-specific.

### Changed

- Vendored **marked bumped from 15.0.12 to 18.0.10** (Dependabot PR #1),
  clearing three years of upstream bug fixes. marked dropped its flat
  `marked.min.js` browser bundle after v15 in favor of `lib/marked.umd.js`;
  `scripts/vendor-webpreview.sh` now tries the old path first and falls back
  to the new one so the vendored file keeps the same name and location.

## [1.5.0] - 2026-08-26

### Changed

- The **Uncommitted** menu row now shows which files changed instead of a
  changed/new/deleted category breakdown, e.g. "2 changes: README.md /
  CHANGELOG.md" instead of "Uncommitted (2 changed)". As many file names are
  listed as fit a reasonable menu width; the rest are collapsed into a
  trailing "…" rather than stretching the menu to fit every one.

### Fixed

- The Web Markdown preview's highlight for changed/added blocks
  (`.gg-mark`) added vertical space around the highlighted block instead of
  only tinting its background. Marking a single changed list item splits it
  into its own `<ul>` (so only that item is highlighted, not the whole
  list — see 1.1.0's "marked an entire list" fix); the wrapper div's vertical
  padding blocked that `<ul>`'s own margin from collapsing normally, and the
  browser's default `~1em` list margin then showed as a gap between
  highlighted and unhighlighted items that a plain, unsplit list never has.
  Fixed by zeroing `.gg-mark`'s vertical padding/margin (so child margins
  collapse straight through the wrapper) and zeroing `ul`/`ol` margin
  (so split list fragments stay flush with their neighbors).

## [1.4.0] - 2026-08-24

### Added

- **Web Markdown preview.** Markdown files gain a built-in **Web** view
  (`WKWebView` + bundled [marked](https://github.com/markedjs/marked) and
  [mermaid.js](https://github.com/mermaid-js/mermaid), offline, no CDN) in
  addition to the existing viewmd **Preview**. Web is available even without
  a viewmd path; `--default-view` accepts `web`. Preview without viewmd falls
  back to Web. Changed blocks still use `viewmd:mark` comments, which the Web
  view wraps in a highlight after parsing.
- **Front-matter table in Web preview.** A leading YAML `---` block is parsed
  (same shape as viewmd: flat keys, nested dotted keys, lists) and shown as a
  Field/Value table above the rendered body.
- **WebPreview dependency audit.** Vendored marked/mermaid are pinned in
  `scripts/webpreview/package.json`. CI runs `npm audit` on every push/PR and
  weekly; Dependabot watches that lockfile. mermaid is 11.17.1 (was 11.6.0)
  to clear a high-severity lodash-es advisory in its tree.
- **Third-party notices.** [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
  lists the vendored marked and mermaid licenses at the repo root.

## [1.3.0] - 2026-08-24

### Added

- **"Open in Finder" / "Open in Terminal"** rows at the bottom of each repo's
  submenu, below a divider, for jumping straight to that repo's folder. Each
  is independently toggleable from Settings → General (both on by default).

### Changed

- **Simplified the repo submenu.** Each repo's Changed/New/Deleted file
  sections (and the "Show all changes" overflow window) are replaced by a
  single **Uncommitted** row summarizing the category counts (e.g.
  "Uncommitted (1 changed, 1 new)"). Clicking it opens a split-view window —
  a sidebar of every changed file plus a colored diff for the selected one —
  matching how clicking a commit already opens that commit's changes. The
  now-unused **Max menu entries** setting/`--max-entries` flag is removed.
- **Flattened "Recent commits" into the repo submenu.** Commits are no longer
  nested in their own "Recent commits" submenu; they're listed directly in
  the repo submenu, below a divider under the Uncommitted row.

## [1.2.0] - 2026-08-23

### Added

- **Multi-repo support.** Gitgleam now watches several repositories from one
  process, instead of one process per repo. The menu bar shows a single
  **aggregated** indicator (color + summed change count) across every
  configured repo; the dropdown lists each repo as its own submenu with its
  own severity icon, Changed/New/Deleted sections, "Show all changes"
  window, and Recent commits submenu. Repos are managed live from a new
  **Repositories** tab in Settings — add one via a folder picker, edit its
  label, re-point its path, pause it without deleting, drag to reorder, or
  remove it, all without restarting. A paused repo is omitted from the
  dropdown (and from the aggregate count) until it's enabled again. Adding
  a folder that isn't a git repo offers to initialize one; a duplicate path
  is warned about. Each repo can override the global warn/critical
  thresholds. Per-repo options (pause, change folder, thresholds, remove)
  sit behind a **⋯** button on each row. A green **Active** / gray **Paused**
  indicator shows whether the repo is being watched. The list warns at 8 repos
  and refuses a 21st. **Export…** / **Import…** write or replace the same JSON
  blob Settings persists in `UserDefaults`. First launch seeds the list from
  repeatable `--repo <path>[:<label>]` flags (or the existing single
  `--path`/`--label`, kept for back-compat); an existing single-repo
  install's settings migrate in automatically.

## [1.1.0] - 2026-08-23

### Added

- A **Settings window** (new "Settings…" menu item, just above Refresh),
  styled as a macOS System Settings-style preferences pane: sidebar
  navigation, section headings, and rounded card rows with a label, a
  one-line explanation, and a flush-right control (sliders with a
  reset-to-default button for numeric values). Every field applies
  immediately and persists per watched path, layered over the CLI flags as
  first-launch defaults:
  - **Info**: app description, version, and a link to the GitHub repository.
  - **General**: a **Language** setting — Automatic (system language) or an
    explicit language from the available translations.
  - **Status icon**: warn/critical thresholds.
  - **Refresh**: poll interval, max menu entries, recent-commits count.
  - **Markdown preview**: viewmd path (with a **Choose…** file-picker
    button), default view, preview width.
  - **Debug**: an option to keep Markdown preview input files in `/tmp`
    instead of deleting them, so the exact Markdown (including `viewmd:mark`
    sentinels) sent to viewmd can be inspected.

### Fixed

- The **Recent commits** submenu closing immediately after opening (see
  1.0.2/1.0.3) in some remaining cases — refreshing is additionally skipped
  now whenever nothing in the status/commit list actually changed, on top of
  pausing while a menu is open.
- Markdown change-highlighting marked an entire list when only one item
  changed, since a "block" was any contiguous run of non-blank lines and a
  tight list has no blank lines between items. Blocks now also split at each
  list-item boundary, so only the changed item (and its indented
  continuation lines) is marked.
- A changed YAML front-matter block was being wrapped in a `viewmd:mark`
  sentinel, which put the comment ahead of the front matter's opening `---`
  and broke viewmd's front-matter detection (it requires `---` as the file's
  literal first line). Front matter is now never marked, changed or not.
- Markdown preview backgrounds rendered too dark in light mode. `Viewmd.render`
  now passes viewmd's `--theme dark`/`light` flag matching the window's
  actual appearance (never `auto`, which needs a terminal query a `Process`
  pipe can't answer); since the installed viewmd doesn't yet act on that flag
  for its `viewmd:mark` highlight color, `ANSIText` also lightens
  256-color/truecolor backgrounds when rendering in light mode as a
  compensating fix.

## [1.0.3] - 2026-08-22

### Fixed

- The **Recent commits** submenu still closing immediately in an actively
  changing repository, even after 1.0.2. That fix only skipped no-op
  refreshes; a genuine change (e.g. an autosaving file elsewhere in the
  watched tree) still rebuilt the menu while the submenu was open. Refreshing
  is now paused for as long as any of the app's own menus is open (tracked
  via AppKit's `NSMenu` tracking notifications) and caught up once it closes.

## [1.0.2] - 2026-08-22

### Fixed

- The **Recent commits** submenu closing immediately after opening. Each
  refresh reassigned its `@Published` state unconditionally, which rebuilt
  the menu even when nothing had changed; since the FSEvents watcher fires
  on any change under the whole tree (including `.git`, which `git status`
  itself touches), a no-op refresh could land right as the submenu opened.
  State is now only reassigned when it actually differs.

## [1.0.1] - 2026-08-22

### Added

- `SECURITY.md`: vulnerability reporting process and a summary of the
  security measures taken during development and testing.
- `CODE_OF_CONDUCT.md`.
- `LICENSE` (MIT).

## [1.0.0] - 2026-08-22

Initial release.

### Added

- Menu-bar-only macOS app (no window, no Dock icon) that watches a git
  repository. A filesystem watcher (FSEvents) triggers an instant
  `git status --porcelain` refresh on any change, with a periodic poll
  (`--interval/-i`, default 60s, clamped to 10–300) as a fallback.
- Menu-bar label with an optional text prefix, a colored dot indicator
  (🟢 green below the warn threshold, 🟡 yellow up to the critical threshold,
  🔴 red at/above it, ⚠️ on a git error), and the uncommitted-change count.
- Dropdown grouping changed files into **Changed**, **New**, and **Deleted**
  sections, plus **Refresh** and **Quit** actions. The list is capped
  (`--max-entries/-m`, default 25); an overflow row opens a **Show all
  changes** window listing every file.
- Clickable changed/new files that open a window with a colored per-file diff.
- A **Recent commits** submenu listing the last `--commits/-C` commits
  (default 10). Clicking one opens a split-view window: a sidebar lists the
  files the commit changed and a detail pane shows the colored diff for the
  selected file (the first file is selected automatically).
- Markdown preview: when `--viewmd-path/-V` points at a `viewmd.sh` launcher,
  the diff window and commit file panes gain a Diff/Preview toggle that
  renders the file as formatted Markdown (including Mermaid diagrams as ASCII
  art), with the changed blocks marked for highlighting. Configurable via
  `--default-view` and `--preview-width`; falls back to the colored diff on
  any viewmd failure.
- Command-line configuration so multiple instances can run side by side:
  `--path/-p`, `--label/-l`, `--warn/-w`, `--critical/-c`, `--interval/-i`,
  `--max-entries/-m`, `--commits/-C`, `--viewmd-path/-V`, `--default-view`,
  `--preview-width`, and `--help/-h`.
- Localization via `L10n` and `.lproj` string tables, honoring the system
  language and a per-launch `-AppleLanguages` override. English (default) and
  Dutch translations included.

[Unreleased]: https://github.com/mo6/gitgleam/compare/v1.7.0...HEAD
[1.7.0]: https://github.com/mo6/gitgleam/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/mo6/gitgleam/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/mo6/gitgleam/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/mo6/gitgleam/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/mo6/gitgleam/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/mo6/gitgleam/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/mo6/gitgleam/compare/v1.0.3...v1.1.0
[1.0.3]: https://github.com/mo6/gitgleam/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/mo6/gitgleam/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/mo6/gitgleam/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/mo6/gitgleam/releases/tag/v1.0.0
