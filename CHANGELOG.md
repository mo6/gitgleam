# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/mo6/gitgleam/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/mo6/gitgleam/compare/v1.0.3...v1.1.0
[1.0.3]: https://github.com/mo6/gitgleam/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/mo6/gitgleam/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/mo6/gitgleam/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/mo6/gitgleam/releases/tag/v1.0.0
