# Gitgleam

A small native macOS menu bar app that watches a git repository and shows the
number of uncommitted changes, colored by severity, with a colored per-file
diff. Built with Swift and SwiftUI. (It began life as "VaultStatus", a hardcoded
watcher for one Obsidian vault, and was generalized into a configurable,
multi-instance tool.)

## What this app does

- Lives in the menu bar only (no window, no Dock icon).
- Refreshes the instant the repo changes: a filesystem watcher (`RepoWatcher`,
  FSEvents) on the watched path triggers `git status --porcelain`. A periodic
  poll (default 60s, `--interval`) is a safety net for anything the watcher
  misses.
- The menu bar label shows an optional text prefix, a colored icon (green below
  the warn threshold, yellow up to the critical threshold, red at/above it), and
  the count. A git error shows a ⚠️ instead.
- The dropdown groups files into **Changed**, **New**, and **Deleted** sections.
  Changed/new files open a colored diff window; deleted files are shown as
  non-clickable text. There is a Refresh and a Quit button. The list is capped at
  `--max-entries` total rows (default 25); when more files exist, an overflow row
  opens a **Show all changes** window (`AllChangesView`) with the full list.
- A **Recent commits** submenu lists the last `--commits` commits (default 10).
  Clicking one opens a `CommitDetailView` split-view window: a sidebar lists the
  files the commit changed and a detail pane (`CommitFilePane`) shows the colored
  diff for the selected file. The first file is selected automatically.
- For **Markdown files**, when `--viewmd-path` points at a `viewmd.sh` launcher,
  the diff window and each commit file pane gain a **Diff/Preview** toggle.
  Preview renders the file as formatted Markdown — including Mermaid diagrams as
  ASCII art — by shelling out to `viewmd` and parsing its ANSI output. Preview is
  the default view for Markdown once viewmd is configured (override with
  `--default-view diff`); a viewmd failure falls back to the colored diff.
  Before rendering, `MarkdownHighlighter` wraps the blocks that changed in
  `viewmd:mark` sentinel comments so viewmd can highlight them (see viewmd issue
  VIEWMD-0104). These are plain HTML comments, invisible to a viewmd that
  doesn't yet support them — so the marking is injected now and simply doesn't
  highlight until viewmd ships that feature.
- The watched path, label, and color thresholds come from command-line flags, so
  several instances can run side by side.

## Build & run

This is a Swift Package Manager project, not an Xcode project. Build and run
from the command line:

```bash
swift build                                  # compile
swift run Gitgleam --path ~/repo --label X   # build and launch
swift build -c release                       # optimized build
```

Flags: `--path/-p`, `--label/-l`, `--warn/-w`, `--critical/-c`, `--interval/-i`,
`--max-entries/-m`, `--commits/-C`, `--viewmd-path/-V`, `--default-view`,
`--preview-width`, `--help/-h` (see `AppConfig.swift`). Path defaults to the
current directory; warn defaults to 1, critical to 10, interval to 60 seconds
(clamped to 10–300; a filesystem watcher gives instant updates, so this is only
a fallback poll), max-entries to 25 (clamped to ≥1), commits to 10 (clamped
to ≥1). `--viewmd-path` is unset by default (Markdown preview disabled);
`--default-view` is `diff`|`preview` (defaults to `preview` once a viewmd path
is set); `--preview-width` defaults to 100 (clamped to ≥20).

The launched app appears in the menu bar (top-right), not the Dock. Quit it from
its own menu ("Quit") or with Ctrl-C in the terminal that ran `swift run`. See
[README.md](README.md) for launch-at-login and multi-instance setup.

Tests live in `Tests/GitgleamTests` (a `.testTarget` in `Package.swift`); run
them with `swift test`. Coverage is the pure logic that needs no running UI or
git: `ANSIText` (SGR + OSC parsing, malformed escapes), `FileKind`, `AppConfig`
flag parsing/clamping, and `MarkdownHighlighter` (diff → block markers). Add
tests here when you add similar logic (e.g. porcelain parsing in `FileChange`).

## Project layout

```
Package.swift                          — SPM manifest (macOS 14+, executable + test target, localized resources)
Sources/Gitgleam/
  GitgleamApp.swift                    — @main App + MenuBarExtra + diff/commit WindowGroups + AppDelegate
  AppConfig.swift                      — parses startup flags (path, label, thresholds, commit count, viewmd preview)
  MenuContent.swift                    — the dropdown menu view (3 sections, capped; recent-commits submenu)
  AllChangesView.swift                 — window listing every change (opened on menu overflow)
  GitMonitor.swift                     — runs git status + recent commits, publishes state, derives color; coalesced refresh
  RepoWatcher.swift                    — FSEvents watcher on the repo tree; triggers an instant refresh on any change
  Git.swift                            — central git runner (status, per-file diff, log, commit diff, file-at-ref), takes a path
  FileChange.swift                     — model: parses a porcelain line into status + path + category
  Commit.swift                         — model: parses a git-log record into sha + subject + author + date
  CommitFile.swift                     — model: parses a name-status line into status + path (one file in a commit)
  DiffView.swift                       — window: working-tree file, colored diff + optional Markdown preview toggle
  CommitDetailView.swift               — commit window: split view (file sidebar + per-file diff pane)
  CommitFilePane.swift                 — detail pane: one commit file, colored diff + optional Markdown preview toggle
  ColoredDiffView.swift                — colored unified-diff renderer (builds an AttributedString from a diff)
  MonospacedTextScroll.swift           — shared scroll shell: one fixed-size monospaced Text (diff + preview)
  ANSIText.swift                       — parses ANSI/SGR escapes into a colored AttributedString (viewmd output)
  Viewmd.swift                         — runs the external viewmd launcher to render Markdown to ANSI
  MarkdownHighlighter.swift            — wraps changed blocks in viewmd:mark sentinels (diff → markers)
  FileKind.swift                       — file-type detection (currently: is this path Markdown?)
  ViewMode.swift                       — enum diff | preview (the window's current/default rendering)
  Localization.swift                   — L10n: central lookup of user-facing strings
  Resources/en.lproj/Localizable.strings — English (default)
  Resources/nl.lproj/Localizable.strings — Dutch (example translation)
Tests/GitgleamTests/                   — unit tests (ANSIText, FileKind, AppConfig, MarkdownHighlighter); run with `swift test`
README.md, CHANGELOG.md                — user-facing docs; CHANGELOG follows Keep a Changelog + SemVer
SECURITY.md, CODE_OF_CONDUCT.md, LICENSE — repo governance docs (LICENSE: MIT)
```

## Architecture notes

- **`MenuBarExtra`** (macOS 13+) is the modern way to build a menu bar app in
  pure SwiftUI. `.menuBarExtraStyle(.menu)` renders the content as a native
  menu (so `Text`/`Button`/`Divider`/`Section` become menu items).
- **No Dock icon:** an `AppDelegate` calls `NSApp.setActivationPolicy(.accessory)`
  in `applicationDidFinishLaunching`. This replaces the `LSUIElement` Info.plist
  key, which a Swift Package does not have.
- **`GitMonitor`** is `@MainActor` because it owns `@Published` state that drives
  the UI. The actual `git` calls live in `Git` as `nonisolated static async`
  functions so the blocking `Process.waitUntilExit()` never freezes the menu.
- **Config flows one way.** `GitgleamApp.config` is parsed once from
  `CommandLine.arguments` and injected into `GitMonitor(config:)` and, via the
  scene closures, into `DiffView` / `CommitDetailView` (repo path plus
  `config.previewSettings`). There is no global mutable state.

## Gotchas (important when editing)

- **Full path to git.** A GUI app does not inherit your shell `PATH`. Always use
  the absolute path `/usr/bin/git` in `Process`, never bare `git`.
- **Watched path comes from flags.** There is no hardcoded path anymore — it is
  `AppConfig.path` (from `--path`, default current directory, `~` expanded).
- **Multiple instances work because it's a raw binary.** Launching the SPM
  executable N times starts N independent processes, each with its own menu-bar
  item. A registered `.app` bundle would refuse a second launch by default
  (`LSMultipleInstancesProhibited`); if this is ever bundled, revisit that.
- **The menu-bar label must be a single `Text`.** A `MenuBarExtra` `.menu`
  label with several sibling views (e.g. `Text` + `Image` + `Text`) is coerced
  into an icon+title layout: it reorders the icon ahead of the text and silently
  drops the extra views (the count disappeared this way). Compose the whole
  label — prefix, icon, count — into one `Text` so order and every part survive.
  Related: an `Image` interpolated into that `Text` is rendered as a monochrome
  *template* (tinted to the menu-bar foreground), which loses any custom color,
  so the severity indicator is a colored circle **emoji** (🟢/🟡/🔴, ⚠️ on
  error) via `statusIcon(for:)`, not an `NSImage`.
- **Localization needs `Bundle.module`.** Strings are looked up from the
  generated `Gitgleam_Gitgleam.bundle` (next to the binary). All user-facing
  text goes through `L10n`; never hardcode a display string in a view. Add a
  language by adding a `Resources/<lang>.lproj/Localizable.strings`.
- **`L10n` picks the language itself.** A raw SPM executable has no localization
  info in `Bundle.main`, so `String(localized:)` / `Bundle.preferredLocalizations`
  ignore the system language and `-AppleLanguages` and always fall back to
  English. `L10n` works around this by matching `Locale.preferredLanguages`
  against `Bundle.module.localizations` and loading that `.lproj` directly. Force
  a language per-launch with the standard override, e.g.
  `swift run Gitgleam -AppleLanguages '(nl)'` (the `(nl)` tuple must be quoted).
- **Diff window vs. accessory policy.** The app runs as `.accessory`, so opening
  the diff `WindowGroup` also calls `NSApp.activate(ignoringOtherApps:)` to pull
  the window to the front. Without that the window can open behind other apps.
- **Untracked file diffs.** `git diff HEAD` does not show untracked files, so
  `Git.diff(for:at:)` special-cases `??` and runs `git diff --no-index --
  /dev/null <file>`. That exits 1 when there are differences (normal), so only an
  exit code > 1 is treated as an error there.
- **Read git's stdout before `waitUntilExit()`.** `Git.run` drains the stdout
  pipe *before* waiting for the process. Waiting first deadlocks on any output
  larger than the OS pipe buffer (~64 KB): git blocks writing into the full pipe
  while we block waiting for it to exit. Large commit diffs exceed that and the
  window spins forever. (stderr for these commands is small, so reading it
  second is safe.)
- **Horizontal diff scrolling needs a single `Text`.** The diff is rendered as
  one monospaced `Text` from an `AttributedString` (`ColoredDiffView`), not a
  `LazyVStack` of per-line `Text`s. A lazy stack sizes its cross axis to the
  viewport rather than to its widest row, so long lines get clipped with nothing
  to scroll to horizontally. A single `.fixedSize()` `Text` grows to the content
  in both axes and scrolls.
- **Markdown preview shells out to viewmd.** `Viewmd.render` launches the
  configured `viewmd.sh` via `/bin/bash` (a GUI app has no shell PATH), on a
  temporary `.md` file, with `--color=always` (a `Process` pipe is not a TTY, so
  viewmd's default `auto` would strip the ANSI we parse), `--no-toc` (a preview
  shows the file's own content, not viewmd's generated navigation outline), and
  `VIEWMD_NO_CONFIG=1` (so a user's viewmd config can't override the
  width/color/toc we ask for). Its ANSI
  output is turned into an `AttributedString` by `ANSIText`; box-drawing/Mermaid
  art only lines up in a monospaced font, which is why the preview reuses
  `MonospacedTextScroll`. Any failure falls back to the colored diff.
  `ANSIText` also strips **OSC 8 hyperlink** escapes (`ESC]8;…`, terminated by
  BEL or ST) — viewmd emits them for its table of contents and wikilinks, and
  without stripping the `]8;…\` machinery leaks into the text; the link *label*
  between the two OSC markers is kept.
- **Change highlighting is done by marking, not by viewmd knowing git.**
  `MarkdownHighlighter.mark` parses the unified diff for added new-file line
  numbers, expands them to blank-line-delimited blocks (fences kept whole), and
  wraps each changed block in `viewmd:mark` sentinels. It reads `self.diff`,
  which the pane loads before the preview, and it copes fine with the
  full-context (`-U1000000`) diffs the app already fetches. Deletions have no
  line in the after-file, so a purely-removed block isn't marked (matches
  VIEWMD-0104's non-goals). Until viewmd implements VIEWMD-0104 the sentinels
  are invisible HTML comments and add a little blank-line spacing around changed
  blocks — the cost of shipping the marking ahead of the renderer.
- **Changing a LaunchAgent's flags needs a reload, not a restart.** `launchctl
  kickstart -k` relaunches with launchd's *cached* `ProgramArguments`, so after
  editing a plist (e.g. adding `--viewmd-path`) you must `launchctl bootout`
  then `bootstrap` the plist for the new args to take effect. `kickstart -k` is
  still correct for a plain rebuild where only the binary changed.
- **The FSEvents watcher covers the whole tree, including `.git`.** A commit
  made outside the app touches `.git` (HEAD/refs/index) but not the working
  files, so watching only the working tree would miss it — hence the whole path
  is watched. `git status` can itself rewrite `.git/index`'s stat cache, which
  produces a follow-up event; FSEvents' 0.5s latency coalescing plus
  `GitMonitor`'s `refreshInFlight`/`pendingRefresh` guard collapse that into a
  single extra refresh rather than a loop. The C callback is a free function
  (`repoWatcherCallback`) that recovers the `RepoWatcher` from FSEvents'
  `info` pointer — a capturing Swift closure can't become a `@convention(c)`
  callback — and hops to `@MainActor` to call `refresh()`.
- **No App Sandbox.** Because this runs via SPM (not a sandboxed .app bundle), it
  can read any repo path directly. A sandboxed distributable would need a
  security-scoped bookmark for paths outside its container.
- **Swift 6 strict concurrency** is on. Keep UI-touching code on `@MainActor`
  and push blocking work into `nonisolated` async functions.
- **`swift test` needs full Xcode, not just Command Line Tools.** The test
  target imports `XCTest`, which the bare CLT install
  (`/Library/Developer/CommandLineTools`) does not ship — it fails with "no
  such module 'XCTest'". `swift build`/`swift run` work fine under CLT alone;
  only `swift test` needs `xcode-select -s /Applications/Xcode.app` pointed at
  a full Xcode install.
- **The repo is public** (`github.com/mo6/gitgleam`), with `develop` as the
  GitHub default branch. Treat anything committed as world-readable: no local
  paths, real usernames, or personal repo names (e.g. the actual watched-vault
  name) in tracked files — check for these before committing, not just before
  making the repo public.

## Conventions

- Swift 6, SwiftUI, no third-party dependencies.
- Code comments and UI text are in English. User-facing strings are localized
  via `L10n` + `.lproj` files, not inline literals.
- Prefer small, single-responsibility files (one type per file).
- **Always auto-commit after a change.** Once a change is complete and builds,
  commit it without waiting to be asked. Use a clear, descriptive commit
  message.
- **Verify `git config user.name`/`user.email` before writing them anywhere.**
  Never hardcode or assume a name/email (in docs, commit `--author`, SECURITY.md
  contact, etc.) — always read the current local git config values first and
  use exactly those, since the user's config is the source of truth and can
  change.
- **Never push to `origin` without approval.** Commit locally freely, but
  always ask before any `git push` (including tags and force-pushes) — pushing
  is a visible, shared-state action that needs explicit confirmation each time.
- **Work on `develop`, not `main`.** Commit to `develop` unless explicitly told
  otherwise; do not create additional feature branches by default. `main` is
  reserved for tagged releases only — it advances by merging `develop` into it
  at release time, then tagging (e.g. `v1.2.0`), not by direct commits.
- **Releasing:** move the `CHANGELOG.md` `[Unreleased]` content under a new
  `## [x.y.z] - <date>` heading (add the compare-link footer entries too),
  commit that on `develop`, fast-forward `main` to `develop`
  (`git merge --ff-only develop`), tag `main` (`git tag -a vX.Y.Z -m "Release
  vX.Y.Z"`), then — after push approval — push `develop`, `main`, and the tag,
  and create the GitHub release (`gh release create vX.Y.Z --title vX.Y.Z
  --notes-file -`) from the same changelog content. Treat an already-pushed
  tag or `main` commit as more durable than `develop` — prefer amending
  unpushed local commits over rewriting history that's already public.
- **Always build release and restart the running instances after a change.**
  The user runs Gitgleam via LaunchAgents that launch the optimized binary
  (`.build/release/Gitgleam`), so a plain `swift build` (debug) is not enough to
  see the effect. After a change is complete, run `swift build -c release`, then
  restart every running instance so the new binary takes effect. Restart the
  LaunchAgents rather than killing the processes:

  ```bash
  swift build -c release
  uid=$(id -u)
  for label in $(ls ~/Library/LaunchAgents | grep -i gitgleam | sed 's/\.plist$//'); do
    launchctl kickstart -k "gui/$uid/$label"
  done
  pgrep -fl -i gitgleam   # confirm fresh PIDs came up
  ```

  Do this without waiting to be asked, the same as auto-committing. The
  LaunchAgent labels are discovered from `~/Library/LaunchAgents/*gitgleam*.plist`
  (currently `nl.mo6.gitgleam.brain` and
  `nl.mo6.gitgleam.brain-private`); if none are present, skip the restart.

## Ideas / backlog

- Click a file to reveal it in Finder, or open the repo in a terminal.
- A "commit"-style action or a shortcut to open the repo in the editor.
- Syntax highlighting inside the diff (currently only +/- lines are colored).
- Package as a real `.app` bundle (Xcode or a bundling script) so it can launch
  at login without a terminal.
