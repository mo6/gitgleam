# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/mo6/gitgleam/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/mo6/gitgleam/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/mo6/gitgleam/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/mo6/gitgleam/releases/tag/v1.0.0
