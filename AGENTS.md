# Gitgleam

A small native macOS menu bar app that watches one or more git repositories
and shows the total number of uncommitted changes, colored by severity, with
a colored per-file diff. Built with Swift and SwiftUI. (It began life as
"VaultStatus", a hardcoded watcher for one Obsidian vault; was generalized
into a configurable, multi-instance tool watching one repo per process; and
was later consolidated into a single multi-repo instance — see "Multi-repo"
below.)

## What this app does

- Lives in the menu bar only (no window, no Dock icon).
- Refreshes the instant a repo changes: a filesystem watcher (`RepoWatcher`,
  FSEvents) on each watched path triggers `git status --porcelain`. A periodic
  poll (default 60s, `--interval`, shared by every repo) is a safety net for
  anything the watcher misses.
- The menu bar label shows a single **aggregated** icon (green below the warn
  threshold, yellow up to the critical threshold, red at/above it — thresholds
  compare against the *summed* change count across every repo) and that summed
  count. A git error in any repo shows a ⚠️ instead.
- The dropdown lists every configured repo as its own submenu (own severity
  icon, label, and count). Inside a repo's submenu: a single **Uncommitted**
  row summarizing the category counts (e.g. "Uncommitted (1 changed, 1 new)"),
  then — below a divider — its last `--commits` commits (default 10), each its
  own row rather than nested in a further submenu. Clicking Uncommitted opens
  an `UncommittedView` split-view window: a sidebar lists every changed file
  grouped into **Changed**, **New**, and **Deleted** sections, and a detail
  pane (`FileDiffPane`) shows the colored diff for the selected file (deleted
  files included — `git diff HEAD` diffs them same as any tracked file).
  Clicking a commit row opens a `CommitDetailView` split-view window: a
  sidebar lists the files the commit changed and a detail pane
  (`CommitFilePane`) shows the colored diff for the selected file. The first
  file is selected automatically. Below the repo list: Settings, Refresh
  (refreshes every repo), and Quit. `UncommittedView`/`CommitDetailView` share
  the same split-view shape (and `FileDiffPane`/`CommitFilePane` the same
  header/diff/preview layout) so uncommitted changes and commits are
  presented consistently — one lists the working tree's changes, the other one
  commit's. Below a further divider, each repo's submenu ends with **Open in
  Finder** and **Open in Terminal** rows for that repo's folder — each
  independently toggleable (on by default) from Settings → General
  (`showOpenInFinder`/`showOpenInTerminal`).
- For **Markdown files**, each file pane (uncommitted or commit) gains a
  **Diff/Web** toggle. **Web** is built in: a `WKWebView` loads bundled
  `preview.html` + marked + mermaid.js (offline) and renders the file as HTML
  with Mermaid as SVG. When `--viewmd-path` points at a `viewmd.sh` launcher,
  a third **Preview** toggle shells out to viewmd and parses its ANSI output
  (Mermaid as ASCII art). Preview is the default once viewmd is configured
  (otherwise Web; override with `--default-view diff|web`); a viewmd failure
  falls back to the colored diff. Before either preview, `MarkdownHighlighter`
  wraps the blocks that changed in `viewmd:mark` sentinel comments. viewmd
  that doesn't yet support them (VIEWMD-0104) ignores the comments; the Web
  view wraps the parsed nodes between them in a highlight.
- The repo list comes from repeatable `--repo <path>[:<label>]` flags at
  first launch (or a single `--path`/`--label`, for back-compat). Everything
  else — the repo list itself, thresholds, poll interval, recent-commits
  count, Markdown preview settings, language, the Open in Finder/Terminal
  row toggles, and a debug option — lives in
  `Settings` (`Settings.swift`), a `@MainActor ObservableObject` seeded once
  from those flags (the first-launch defaults) then persisted independently
  via `UserDefaults` under one global key. `SettingsView` (opened from a new
  menu item, "Settings…", just above Refresh) edits it live: `AppMonitor`
  observes `Settings.repos` (creating/destroying a `RepoMonitor` per entry)
  and forwards `Settings`' other changes, and any uncommitted/commit window
  opened afterwards reads the current values.
- **Language** is one of those settings: "Automatic" (the previous,
  system-language-only behavior) or an explicit language, applied via
  `L10n.languageOverride`.

## Multi-repo

One process now watches every configured repo and shows one aggregated
menu-bar indicator, instead of running one process per repo:

- `RepoConfig` (`RepoConfig.swift`) is the unit: a stable `UUID` plus
  `path`/`label`, an `isEnabled` flag, and optional per-repo warn/critical
  overrides. `Settings.repos: [RepoConfig]` is the source of truth, editable
  live from **Settings… → Repositories** (add via a folder picker, edit the
  label inline, re-point the path, pause without deleting, drag to reorder,
  export/import the JSON blob, or delete). Adding a non-git folder offers
  `git init`; duplicate paths are warned; the list warns at 8 repos and
  caps at 20.
- `RepoMonitor` (`RepoMonitor.swift`, the renamed/reworked former
  `GitMonitor`) tracks one *enabled* repo — unchanged in spirit from before
  multi-repo, just constructed from a `RepoConfig` instead of the whole
  `AppConfig`. Its yellow/red boundaries use that repo's threshold override
  when set, otherwise the global Settings values.
- `AppMonitor` (`AppMonitor.swift`) owns one `RepoMonitor` per *enabled*
  entry in `settings.repos`, rebuilding that dictionary whenever the list
  changes (a path edit recreates the monitor — the watcher and cached state
  are path-bound; pausing tears it down; a label-only edit doesn't), and
  exposes the aggregate status/count the menu bar shows (paused repos are
  omitted from the sum and from the dropdown). It also owns the single pair of `NSMenu`
  tracking observers that pause every repo's refresh while a menu is open
  (see the "Refreshing pauses..." gotcha below) — `RepoMonitor` itself no
  longer registers its own.
- `RepoCommit` (`RepoCommit.swift`) bundles a repo's id/path with a `Commit`
  for `openWindow(id:value:)` — the commit window needs to know *which* repo a
  commit belongs to, now that several repos can be open at once. The
  Uncommitted window instead takes just the repo `UUID` (see `GitgleamApp`)
  since it shows every file at once rather than one. `Commit`/`FileChange`
  themselves stay untouched, pure parse models.
- Settings storage moved from a per-watched-path key
  (`"nl.mo6.gitgleam.settings.\(path)"`, one process per repo) to one global
  key (`Settings.storageKey`, one process for every repo). `Settings.init`
  migrates an existing per-path blob the first time it finds nothing under
  the global key and this launch's first `--repo`/`--path` matches one — see
  the `Settings` gotcha below.

## Build & run

This is a Swift Package Manager project, not an Xcode project. Build and run
from the command line:

```bash
swift build                                              # compile
swift run Gitgleam --repo ~/repo:X --repo ~/other:Y      # build and launch
swift build -c release                                   # optimized build
```

Flags: `--repo/-r` (repeatable, `<path>[:<label>]`), `--path/-p`,
`--label/-l` (single-repo back-compat for `--repo`), `--warn/-w`,
`--critical/-c`, `--interval/-i`, `--commits/-C`,
`--viewmd-path/-V`, `--default-view`, `--preview-width`, `--help/-h` (see
`AppConfig.swift`). No `--repo`/`--path` at all seeds one repo at the current
directory. Warn defaults to 1, critical to 10, interval to 60 seconds
(clamped to 10–300; a filesystem watcher gives instant updates, so this is only
a fallback poll), commits to 10 (clamped to ≥1). `--viewmd-path` is unset by
default (no viewmd Preview toggle; the built-in Web preview still works);
`--default-view` is `diff`|`preview`|`web` (defaults to `preview`, which falls
back to Web without viewmd); `--preview-width` defaults to 100 (clamped to ≥20).
All of these are only *first-launch* defaults — `Settings` takes over from
there (the repo list included), editable live in the Settings window and
persisted independently.

The launched app appears in the menu bar (top-right), not the Dock. Quit it from
its own menu ("Quit") or with Ctrl-C in the terminal that ran `swift run`. See
[README.md](README.md) for launch-at-login setup.

Tests live in `Tests/GitgleamTests` (a `.testTarget` in `Package.swift`); run
them with `swift test`. Coverage is the pure logic that needs no running UI or
git: `ANSIText` (SGR + OSC parsing, malformed escapes, light-mode background
adaptation), `FileKind`, `RepoConfig` (`Codable` round-trip), `AppConfig` flag
parsing/clamping (including the repeatable `--repo` flag and `--path`/
`--label` back-compat), `Settings` (seeding from `AppConfig`, clamping,
persistence round-trip including `repos`, backward-compatible decoding, the
legacy-per-path-key migration), `ViewMode.initial` (Markdown default-view
fallback), `MarkdownHighlighter` (diff → block markers, list-item/front-
matter splitting), and WebPreview pin lockstep (`NOTICE.txt` vs
`scripts/webpreview/package.json` vs the vendored JS headers). Known
advisories against those pins are checked by `scripts/check-webpreview-deps.sh`
(`npm audit`, run in GitHub Actions and locally when node is available).
Add tests here when you add similar logic (e.g. porcelain parsing in
`FileChange`). There's no dedicated coverage for `RepoMonitor`/`AppMonitor`
(as there wasn't for `GitMonitor` before them) — they need a running git
process/FSEvents/UI to exercise.

## Project layout

```
Package.swift                          — SPM manifest (macOS 14+, executable + test target, localized resources)
Sources/Gitgleam/
  GitgleamApp.swift                    — @main App + MenuBarExtra + uncommitted/commit WindowGroups + AppDelegate
  AppConfig.swift                      — parses startup flags (initial repo list, thresholds, commit count, viewmd preview)
  RepoConfig.swift                     — model: one watched repo (stable UUID + path + label), persisted in Settings.repos
  MenuContent.swift                    — the dropdown menu view: one submenu per repo (Uncommitted row + recent-commits submenu)
  UncommittedView.swift                — window: split view of every uncommitted file (file sidebar + per-file diff pane)
  AppMonitor.swift                     — owns one RepoMonitor per settings.repos entry; aggregates status/count for the menu bar
  RepoMonitor.swift                    — runs git status + recent commits for one repo, publishes state, derives color; coalesced refresh
  RepoCommit.swift                     — RepoCommit: Commit bundled with which repo, for openWindow
  RepoWatcher.swift                    — FSEvents watcher on one repo tree; triggers an instant refresh on any change
  Git.swift                            — central git runner (status, per-file diff, log, commit diff, file-at-ref), takes a path
  FileChange.swift                     — model: parses a porcelain line into status + path + category
  Commit.swift                         — model: parses a git-log record into sha + subject + author + date
  CommitFile.swift                     — model: parses a name-status line into status + path (one file in a commit)
  FileDiffPane.swift                   — detail pane: one uncommitted file, colored diff + Markdown Diff/Web/Preview toggle
  CommitDetailView.swift               — commit window: split view (file sidebar + per-file diff pane)
  CommitFilePane.swift                 — detail pane: one commit file, colored diff + Markdown Diff/Web/Preview toggle
  ColoredDiffView.swift                — colored unified-diff renderer (builds an AttributedString from a diff)
  MonospacedTextScroll.swift           — shared scroll shell: one fixed-size monospaced Text (diff + viewmd preview)
  ANSIText.swift                       — parses ANSI/SGR escapes into a colored AttributedString (viewmd output)
  Viewmd.swift                         — runs the external viewmd launcher to render Markdown to ANSI
  WebPreviewView.swift                 — WKWebView Markdown/Mermaid preview (bundled marked + mermaid.js)
  MarkdownViewPicker.swift             — segmented Diff / Preview / Web control
  WebPreview/                          — preview.html, preview.js, vendored marked.min.js + mermaid.min.js
  MarkdownHighlighter.swift            — wraps changed blocks in viewmd:mark sentinels (diff → markers)
  FileKind.swift                       — file-type detection (currently: is this path Markdown?)
  ViewMode.swift                       — enum diff | preview | web (the window's current/default rendering)
  Settings.swift                       — live, persisted defaults (repos, thresholds, interval, viewmd, language, debug flag); export/import JSON
  SettingsView.swift                   — the Settings window: sidebar sections + card rows
  RepositoriesSettingsView.swift       — Settings Repositories tab (pause, reorder, thresholds, export/import)
  AppInfo.swift                        — static version string + GitHub URL, shown in Settings' Info section
  Localization.swift                   — L10n: central lookup of user-facing strings + language-override support
  Resources/en.lproj/Localizable.strings — English (default)
  Resources/nl.lproj/Localizable.strings — Dutch (example translation)
Tests/GitgleamTests/                   — unit tests (ANSIText, FileKind, RepoConfig, AppConfig, Settings, ViewMode, MarkdownHighlighter, WebPreview pins); run with `swift test`
scripts/check-webpreview-deps.sh       — npm audit + version sync for vendored marked/mermaid
scripts/vendor-webpreview.sh           — re-download WebPreview JS to match scripts/webpreview/package.json
scripts/webpreview/                    — package.json + lockfile (audit/Dependabot only; not shipped)
.github/workflows/ci.yml               — runs the WebPreview dependency audit on push/PR/weekly
.github/dependabot.yml                 — weekly npm PRs for scripts/webpreview
README.md, CHANGELOG.md, IMPROVEMENTS.md — user-facing docs + living product backlog; CHANGELOG follows Keep a Changelog + SemVer
SECURITY.md, CODE_OF_CONDUCT.md, LICENSE — repo governance docs (LICENSE: MIT)
```

## Architecture notes

- **`MenuBarExtra`** (macOS 13+) is the modern way to build a menu bar app in
  pure SwiftUI. `.menuBarExtraStyle(.menu)` renders the content as a native
  menu (so `Text`/`Button`/`Divider`/`Section` become menu items).
- **No Dock icon:** an `AppDelegate` calls `NSApp.setActivationPolicy(.accessory)`
  in `applicationDidFinishLaunching`. This replaces the `LSUIElement` Info.plist
  key, which a Swift Package does not have.
- **`RepoMonitor`/`AppMonitor`** are `@MainActor` because they own `@Published`
  state that drives the UI. The actual `git` calls live in `Git` as
  `nonisolated static async` functions so the blocking `Process.waitUntilExit()`
  never freezes the menu.
- **Config flows one way.** `GitgleamApp.config` is parsed once from
  `CommandLine.arguments` and used only to seed `Settings` (repo list,
  thresholds, preview settings). From then on the scene closures read
  `settings`/`monitor` (an `AppMonitor`) directly — `UncommittedView` gets its
  repo from the `UUID` passed to `openWindow` (looked up in `monitor`/
  `settings` at open time), and `CommitDetailView` from the `RepoCommit` value
  passed the same way, not from a static config. There is no global mutable
  state.

## Gotchas (important when editing)

- **Full path to git.** A GUI app does not inherit your shell `PATH`. Always use
  the absolute path `/usr/bin/git` in `Process`, never bare `git`.
- **Watched paths come from `Settings.repos`.** There is no hardcoded path —
  each `RepoConfig.path` is seeded from `--repo`/`--path` at first launch
  (`~` expanded) and can change any time from Settings' Repositories tab.
- **Multiple instances still work, but aren't the intended way to watch
  several repos anymore.** Launching the SPM executable N times still starts N
  independent processes, each with its own aggregated menu-bar item (each
  process's `Settings` reads/writes the same global `UserDefaults` key, so
  running two at once would fight over the same repo list — avoid it). A
  registered `.app` bundle would refuse a second launch by default
  (`LSMultipleInstancesProhibited`); if this is ever bundled, revisit that.
- **The menu-bar label must be a single `Text`.** A `MenuBarExtra` `.menu`
  label with several sibling views (e.g. `Text` + `Image` + `Text`) is coerced
  into an icon+title layout: it reorders the icon ahead of the text and silently
  drops the extra views (the count disappeared this way). Compose the whole
  label — icon, count — into one `Text` so order and every part survive.
  Related: an `Image` interpolated into that `Text` is rendered as a monochrome
  *template* (tinted to the menu-bar foreground), which loses any custom color,
  so the severity indicator is a colored circle **emoji** (🟢/🟡/🔴, ⚠️ on
  error) via `statusIcon(for:)` (top-level, aggregate) and `MenuContent`'s own
  `statusIcon(for:)` (per repo, in its submenu title), not an `NSImage`.
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
- **Uncommitted/commit windows vs. accessory policy.** The app runs as
  `.accessory`, so opening the Uncommitted or commit `WindowGroup` also calls
  `NSApp.activate(ignoringOtherApps:)` to pull the window to the front.
  Without that the window can open behind other apps.
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
  shows the file's own content, not viewmd's generated navigation outline),
  `--theme dark`/`light` matching the window's actual `colorScheme` (`auto`
  needs a terminal OSC 11 query a `Process` pipe can't answer — see the
  ANSIText bullet below for why this alone isn't yet enough), and
  `VIEWMD_NO_CONFIG=1` (so a user's viewmd config can't override the
  width/color/toc/theme we ask for). Its ANSI
  output is turned into an `AttributedString` by `ANSIText`; box-drawing/Mermaid
  art only lines up in a monospaced font, which is why the preview reuses
  `MonospacedTextScroll`. Any failure falls back to the colored diff.
  `ANSIText` also strips **OSC 8 hyperlink** escapes (`ESC]8;…`, terminated by
  BEL or ST) — viewmd emits them for its table of contents and wikilinks, and
  without stripping the `]8;…\` machinery leaks into the text; the link *label*
  between the two OSC markers is kept.
- **`ANSIText` compensates for viewmd's `--theme` not doing anything yet.**
  As of the installed viewmd version, `--theme dark` and `--theme light`
  produce byte-identical ANSI — including the `viewmd:mark` highlight
  background, a fixed dark-tuned truecolor that reads as a muddy box on a
  light-mode window. `ANSIText.attributed(from:colorScheme:)` lightens
  256-color/truecolor *backgrounds* (`48;5;n`/`48;2;r;g;b`) toward white when
  `colorScheme == .light`, tracked via `Style.backgroundIsExtended`. The 16
  basic ANSI colors (`40`-`47`/`100`-`107`, mapped to `.primary`/`.secondary`/
  etc.) are already theme-aware and untouched. Revisit this once viewmd
  actually varies its palette by `--theme`.
- **Change highlighting is done by marking, not by viewmd knowing git.**
  `MarkdownHighlighter.mark` parses the unified diff for added new-file line
  numbers, expands them to blocks — maximal runs of non-blank lines, with a
  fenced code block kept whole and a run additionally split at each list-item
  boundary (so one changed item in a tight list marks just that item, not the
  whole list) — and wraps each changed block in `viewmd:mark` sentinels. A
  leading YAML front-matter block is never marked, changed or not: wrapping it
  puts the sentinel ahead of its opening `---`, which breaks viewmd's
  front-matter detection (it requires `---` as the file's literal first
  line — see `frontMatterLineCount`). It reads `self.diff`,
  which the pane loads before the preview, and it copes fine with the
  full-context (`-U1000000`) diffs the app already fetches. Deletions have no
  line in the after-file, so a purely-removed block isn't marked (matches
  VIEWMD-0104's non-goals). Until viewmd implements VIEWMD-0104 the sentinels
  are invisible HTML comments and add a little blank-line spacing around changed
  blocks — the cost of shipping the marking ahead of the renderer. The Web
  preview already wraps those comments in a highlight after `marked` parses.
- **Web Markdown preview is a bundled `WKWebView`.** `WebPreviewView` loads
  `preview.html` with `loadFileURL` from the `WebPreview/` resource folder
  (`Package.swift` uses `.copy("WebPreview")` so the JS files aren't flattened
  or mangled). marked 15.0.12 and mermaid 11.17.1 are vendored there; no CDN.
  Swift injects the Markdown via `callAsyncJavaScript` after the page
  finishes loading. Theme follows `colorScheme`. Do **not** wrap Markdown in
  a block HTML tag before parse — CommonMark will not parse inside it; wrap
  the resulting DOM nodes between the `viewmd:mark` comments instead. A
  leading YAML front-matter block is stripped before `marked` and rendered as
  a Field/Value HTML table (viewmd's split/flatten rules: nested keys become
  dotted, empty fields are omitted).
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
  `RepoMonitor`'s `refreshInFlight`/`pendingRefresh` guard collapse that into a
  single extra refresh rather than a loop. The C callback is a free function
  (`repoWatcherCallback`) that recovers the `RepoWatcher` from FSEvents'
  `info` pointer — a capturing Swift closure can't become a `@convention(c)`
  callback — and hops to `@MainActor` to call `refresh()`.
- **Refreshing pauses while any of the app's own menus is open.**
  `AppMonitor` (not each `RepoMonitor` — see "Multi-repo" above) observes
  AppKit's in-process `NSMenu.didBeginTrackingNotification`/
  `didEndTrackingNotification` and defers every repo's `refresh()` (reusing
  each `RepoMonitor`'s `pendingRefresh` flag via `menuOpened()`/
  `menuClosed()`) for as long as one is open, catching up once it closes.
  Without this, a refresh mid-open — even a no-op one — fires
  `objectWillChange` and rebuilds the menu, which was closing the "Recent
  commits" submenu the instant it opened. Neither class is an `NSObject`, so
  this uses the block-based `NotificationCenter` API, not target/selector.
- **`Settings` persists under one global key, with optional fields for
  forward-compatible decoding.** `Settings` (`@MainActor ObservableObject`)
  is seeded once from `AppConfig` (the CLI flags — first-launch defaults
  only) and thereafter reads/writes a single JSON-encoded `StoredSettings`
  blob in `UserDefaults`, keyed by the fixed `Settings.storageKey`
  (`"nl.mo6.gitgleam.settings"`) — one blob for every repo, since one process
  now watches all of them. Before multi-repo it was keyed per watched path
  (`"nl.mo6.gitgleam.settings.\(path)"`, one process per repo); `Settings.init`
  migrates a matching legacy blob in place the first time it finds nothing
  under the global key (see `SettingsTests.testDataWithoutLanguageOrReposKeysStillDecodes`).
  A field added after the app has already persisted settings for someone
  must be declared `Optional` in `StoredSettings` (Codable's synthesized
  decoder treats a missing key as `nil` for an `Optional` property, but fails
  the *entire* decode for a missing required field) — see `language`/`repos`
  for the pattern. Assignments inside `Settings.init` don't trigger a
  property's own `didSet` (a general Swift rule), so the clamping/persisting/
  side-effecting logic in each property's `didSet` needs an explicit one-time
  equivalent at the end of `init` when it has an effect beyond the property
  itself (e.g. `L10n.languageOverride`, set explicitly after `language`'s
  assignment).
- **`L10n`'s language override is `nonisolated(unsafe)`, deliberately.**
  `Settings.language` calls `L10n.languageOverride = ...`, but `L10n` is also
  called from `Git`'s `nonisolated` background functions (`gitFailed`, etc.),
  so it can't be `@MainActor`-isolated without restructuring `Git`'s
  concurrency model. `languageOverride`/`bundleCache` are marked
  `nonisolated(unsafe)` instead, accepting a benign race on the rare
  read-during-write over that restructuring, for a display-string cache.
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
  bump `AppInfo.version` (shown in Settings → Info — it has no runtime
  source, so this is the only place it changes), commit that on `develop`,
  fast-forward `main` to `develop`
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
  (currently just `nl.mo6.gitgleam.brain`, which watches every configured repo
  — see "Multi-repo" above); if none are present, skip the restart.

## Ideas / backlog

- Click a file to reveal it in Finder, or open the repo in a terminal.
- A "commit"-style action or a shortcut to open the repo in the editor.
- Syntax highlighting inside the diff (currently only +/- lines are colored).
- Package as a real `.app` bundle (Xcode or a bundling script) so it can launch
  at login without a terminal.
