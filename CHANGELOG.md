# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-08-20

### Added

- A **Recent commits** submenu listing the last `--commits` commits (default 10,
  clamped to ≥1). Each menu entry shows the commit date/time, short SHA and
  subject. Clicking a commit opens a split-view window: a sidebar lists the files
  the commit changed and a detail pane shows the colored diff for the selected
  file (the first file is selected automatically). The per-file and per-commit
  diff panes share a common colored-diff renderer (`ColoredDiffView`).

### Fixed

- Diff windows no longer hang on large diffs. `git`'s output is now read before
  waiting for the process to exit, avoiding a pipe-buffer deadlock that froze the
  window whenever a diff exceeded ~64 KB.
- Long lines in a diff can now be scrolled to horizontally (the diff is rendered
  as a single `Text` that grows to its content width).
- A diff shorter than the window is aligned to the top-left instead of being
  vertically centered.

## [1.0.1] - 2026-07-29

### Added

- Configurable cap on the number of file rows in the dropdown menu
  (`--max-entries/-m`, default 25) so a large update no longer overruns the menu.
  When files are hidden, an overflow indicator (`N more not shown`) and a
  **Show all N changes…** button appear; the button opens a resizable window
  listing every change, grouped into Changed / New / Deleted, with the same
  clickable diffs as the menu.

### Changed

- Documented the single-`Text` menu-bar label gotcha in `CLAUDE.md`.

## [1.0.0] - 2026-07-29

Initial release.

### Added

- Menu-bar-only macOS app (no window, no Dock icon) that watches a git
  repository and polls `git status --porcelain`.
- Menu-bar label with an optional text prefix, a colored dot indicator
  (🟢 green below the warn threshold, 🟡 yellow up to the critical threshold,
  🔴 red at/above it, ⚠️ on a git error), and the uncommitted-change count.
- Dropdown grouping changed files into **Changed**, **New**, and **Deleted**
  sections, plus **Refresh** and **Quit** actions.
- Clickable changed/new files that open a window with a summary and a colored
  per-file diff.
- Command-line configuration so multiple instances can run side by side:
  `--path/-p`, `--label/-l`, `--warn/-w`, `--critical/-c`, `--interval/-i`
  (default 30s, clamped to 10–300), and `--help/-h`.
- Localization via `L10n` and `.lproj` string tables, honoring the system
  language and a per-launch `-AppleLanguages` override. English (default) and
  Dutch translations included.

[Unreleased]: https://github.com/mo6/gitgleam/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/mo6/gitgleam/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/mo6/gitgleam/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/mo6/gitgleam/releases/tag/v1.0.0
