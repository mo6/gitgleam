# Gitgleam

A tiny native macOS menu bar app that watches one or more git repositories and
shows the total number of uncommitted changes, colored by severity. Click a
changed file to see a colored diff. Built with Swift + SwiftUI
(`MenuBarExtra`).

- Lives in the menu bar only (no window, no Dock icon).
- Refreshes the instant a repo changes (a filesystem watcher on each watched
  path), with a periodic `git status --porcelain` poll as a safety net (default
  60s, configurable via `--interval`).
- The menu-bar label is a single **aggregated** indicator across every
  configured repo: a colored dot (🟢 green below the warn threshold, 🟡 yellow
  up to the critical threshold, 🔴 red at/above it — or ⚠️ if any repo has a
  git error) and the summed change count.
- The dropdown lists every configured repo as its own submenu (with its own
  severity icon and count): an **Uncommitted** row summarizing the change
  counts (e.g. "1 changed, 1 new"), then — below a divider — its last few
  commits (default 10, configurable via `--commits`), each its own row.
  Clicking Uncommitted opens a split-view window with a sidebar of every
  changed file — grouped into **Changed**, **New**, and **Deleted** — and a
  colored diff for the selected file; clicking a commit opens the same kind
  of split-view window for the files that commit changed. Each repo's
  submenu ends with **Open in Finder** / **Open in Terminal** rows for its
  folder (each can be turned off in Settings; both on by default).
- **Markdown files** can be previewed as formatted Markdown — including Mermaid
  diagrams — instead of a raw diff. A built-in **Web** view (HTML + mermaid.js)
  is always available; a [viewmd](https://github.com/mo6/viewmd) **Preview**
  (ANSI art) appears when a launcher is configured via `--viewmd-path`. The
  Uncommitted and commit windows show a Diff/Web toggle, plus Preview when
  viewmd is set. Preview is the default once viewmd is configured (otherwise
  Web).
- The repo list is set via `--repo` flags at first launch, then managed live
  from **Settings… → Repositories** (add, relabel, re-point, or remove a
  repo — no restart needed). Everything else — thresholds, poll interval,
  recent-commits count, Markdown preview settings, language, the Open in
  Finder/Terminal row toggles, and a debug option — also lives in
  **Settings…** (menu item, above Refresh) and applies immediately; the
  flags below are just its first-launch defaults, persisted independently
  afterwards.

## Requirements

- macOS 14+
- Xcode / Swift toolchain (Swift 6)

## Run

From the project directory:

```bash
swift run Gitgleam --repo ~/code/my-repo:Work --repo ~/notes:Notes
```

The app appears in the menu bar (top-right), not the Dock. Quit via its own
menu ("Quit"), or with Ctrl-C in the terminal that ran `swift run`.

### Options

```
-r, --repo <path>[:<label>]  Repository to watch, optionally labeled;
                             repeat for several repos (default: current
                             directory)
-p, --path <dir>       Repository to watch (single-repo shorthand for
                       --repo; ignored if --repo is given)
-l, --label <text>     Label for the --path repo
-w, --warn <n>         Change count at/above which the icon is yellow (default: 1)
-c, --critical <n>     Change count at/above which the icon is red (default: 10)
-i, --interval <secs>  Safety-net poll interval; a filesystem watcher refreshes
                       instantly (default: 60, min: 10, max: 300)
-C, --commits <n>      Recent commits listed in the submenu (default: 10)
-V, --viewmd-path <p>  Path to viewmd.sh; enables the viewmd Preview toggle
    --default-view <v> Initial view for a Markdown file: diff | preview | web
                       (default: preview, which falls back to web without viewmd)
    --preview-width <n> Columns passed to viewmd for previews (default: 100)
-h, --help             Show this help and exit
```

These are only first-launch defaults for a fresh install — after that, the
repo list and every other setting are edited live from **Settings…** and
persist independently, regardless of what's passed on the command line.

Color logic: `count == 0` (below `--warn`) is green, `--warn ≤ count < --critical`
is yellow, `count ≥ --critical` is red. A git error shows a ⚠️ instead.

### Markdown preview

Markdown files in the Uncommitted and commit windows have a **Diff / Web**
toggle. **Web** is built in: it renders the file as HTML with Mermaid diagrams
as SVG, using copies of marked and mermaid.js shipped in the app (no network).
Changed blocks are highlighted from the same `viewmd:mark` comments the
viewmd path uses. A leading YAML front-matter block renders as a Field/Value
table above the body.

**Preview** (viewmd) is optional. `--viewmd-path` must point at an installed
[viewmd](https://github.com/mo6/viewmd) launcher (`viewmd.sh`, with its
virtualenv set up per viewmd's README). Gitgleam runs it per file to render
formatted Markdown — including Mermaid diagrams as ASCII art. If viewmd is
missing or errors, Preview falls back to the colored diff, so the flag is safe
to leave set.

Gitgleam also marks the blocks that changed so viewmd can highlight them; this
needs a viewmd that understands the `viewmd:mark` markers (viewmd issue
VIEWMD-0104). Until then the markers are invisible in Preview. The Web view
already wraps those comments in a highlight.

```bash
.build/release/Gitgleam --repo ~/notes:Notes \
    --viewmd-path ~/Projects/viewmd/viewmd.sh
```

`swift run` keeps the launching terminal occupied. For everyday use — and to
launch at login — build an optimized binary once and run that:

```bash
swift build -c release                             # produces .build/release/Gitgleam
.build/release/Gitgleam --repo ~/code/my-repo      # launch it
```

To watch more repos later, add them from **Settings… → Repositories** — no
need to relaunch with more `--repo` flags.

## Start automatically at login

Because this is a Swift Package (not a bundled `.app`), macOS's built-in
"Open at Login" list can't manage it directly. Instead, register the release
binary as a **LaunchAgent** — a small plist that `launchd` starts for you each
time you log in. One instance is enough for every repo you want to watch: add
more repos afterwards from Settings rather than creating another LaunchAgent.

1. **Build the release binary** (once, and again after any code change):

   ```bash
   swift build -c release
   ```

   This creates `.build/release/Gitgleam` inside the project folder.
   Keep the generated `Gitgleam_Gitgleam.bundle` (localized strings) next to the
   binary — moving the binary alone drops the translations.

2. **Create the LaunchAgent** at
   `~/Library/LaunchAgents/nl.mo6.gitgleam.plist`. Seed it with as many
   `--repo` entries as you like — or just one, and add the rest later from
   Settings. launchd does **not** expand `~`, so use absolute paths and
   replace `/Users/you` with your home directory:

   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
     "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>Label</key>
       <string>nl.mo6.gitgleam</string>

       <key>ProgramArguments</key>
       <array>
           <string>/Users/you/Projects/Gitgleam/.build/release/Gitgleam</string>
           <string>--repo</string>
           <string>/Users/you/code/my-repo:Work</string>
       </array>

       <!-- Start at login and keep it running. -->
       <key>RunAtLoad</key>
       <true/>
       <key>KeepAlive</key>
       <true/>

       <!-- Logs, handy while getting it working. -->
       <key>StandardOutPath</key>
       <string>/tmp/gitgleam.out.log</string>
       <key>StandardErrorPath</key>
       <string>/tmp/gitgleam.err.log</string>
   </dict>
   </plist>
   ```

3. **Load it** (starts it now and enables it at every login):

   ```bash
   launchctl load ~/Library/LaunchAgents/nl.mo6.gitgleam.plist
   ```

   The menu bar icon should appear within a second or two.

### Managing the LaunchAgent

```bash
# Stop it and disable auto-start
launchctl unload ~/Library/LaunchAgents/nl.mo6.gitgleam.plist

# Restart after rebuilding the binary
launchctl unload ~/Library/LaunchAgents/nl.mo6.gitgleam.plist
launchctl load   ~/Library/LaunchAgents/nl.mo6.gitgleam.plist

# Check whether launchd considers it running (look for the Label in the list)
launchctl list | grep gitgleam
```

If it doesn't appear, check `/tmp/gitgleam.err.log` for errors.

> **Tip:** because the LaunchAgent points at the compiled binary, changes to the
> source only take effect after you re-run `swift build -c release` and reload
> the agent.

## Language

By default the UI follows your macOS system language, falling back to
English. Open **Settings… → General** to pick an explicit language instead of
"Automatic". Translations live in
`Sources/Gitgleam/Resources/<lang>.lproj/Localizable.strings` and are looked
up via the `L10n` helper. A Dutch (`nl`) translation is included as an
example; add a language by dropping in a new `.lproj` folder and translating
the values — it then also appears as a choice in Settings.

Force a language for a single launch with the standard `-AppleLanguages`
override (the tuple must be quoted), which is what "Automatic" honors:

```bash
swift run Gitgleam --repo ~/repo -AppleLanguages '(nl)'
```

See [CLAUDE.md](CLAUDE.md) for architecture and development notes.

## License

Gitgleam is MIT; see [LICENSE](LICENSE). Notices for the JavaScript vendored
into the Markdown Web preview are in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
