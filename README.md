# Gitgleam

A tiny native macOS menu bar app that watches a git repository and shows the
number of uncommitted changes, colored by severity. Click a changed file to see
a colored diff. Built with Swift + SwiftUI (`MenuBarExtra`).

- Lives in the menu bar only (no window, no Dock icon).
- Refreshes the instant the repo changes (a filesystem watcher on the watched
  path), with a periodic `git status --porcelain` poll as a safety net (default
  60s, configurable via `--interval`).
- The label shows an optional text prefix, a colored dot indicator (🟢 green
  below the warn threshold, 🟡 yellow up to the critical threshold, 🔴 red
  at/above it — or ⚠️ on a git error), and the count.
- The dropdown groups files into **Changed**, **New**, and **Deleted** sections.
  Changed/new files open a colored diff window; deleted files are shown as text.
  The list is capped (default 25, configurable via `--max-entries`); when a large
  update exceeds the cap, an overflow row opens a **Show all changes** window
  listing everything.
- A **Recent commits** submenu lists the last few commits (default 10,
  configurable via `--commits`); clicking one opens a split-view window with a
  sidebar of the files it changed and a colored diff for the selected file.
- **Markdown files** can be previewed as formatted Markdown — including Mermaid
  diagrams — instead of a raw diff, when a [viewmd](https://github.com/mo6/viewmd)
  launcher is configured via `--viewmd-path`. The diff and commit windows then
  show a Diff/Preview toggle (Preview is the default for Markdown).
- The watched path and label are set via flags, so you can run several
  instances at once. Everything else — thresholds, poll interval, menu
  entry cap, recent-commits count, Markdown preview settings, language, and
  a debug option — has a **Settings…** window (menu item, above Refresh)
  where it can be changed live, no restart needed; the flags below are just
  its first-launch defaults, persisted per watched path afterwards.

## Requirements

- macOS 14+
- Xcode / Swift toolchain (Swift 6)

## Run

From the project directory:

```bash
swift run Gitgleam --path ~/code/my-repo --label "Work"
```

The app appears in the menu bar (top-right), not the Dock. Quit via its own
menu ("Quit"), or with Ctrl-C in the terminal that ran `swift run`.

### Options

```
-p, --path <dir>       Repository to watch (default: current directory)
-l, --label <text>     Text shown before the menu-bar indicator
-w, --warn <n>         Change count at/above which the icon is yellow (default: 1)
-c, --critical <n>     Change count at/above which the icon is red (default: 10)
-i, --interval <secs>  Safety-net poll interval; a filesystem watcher refreshes
                       instantly (default: 60, min: 10, max: 300)
-m, --max-entries <n>  Max file rows in the menu before overflow (default: 25)
-C, --commits <n>      Recent commits listed in the submenu (default: 10)
-V, --viewmd-path <p>  Path to viewmd.sh; enables the Markdown Preview toggle
    --default-view <v> Initial view for a Markdown file: diff | preview
                       (default: preview, when --viewmd-path is set)
    --preview-width <n> Columns passed to viewmd for previews (default: 100)
-h, --help             Show this help and exit
```

Color logic: `count == 0` (below `--warn`) is green, `--warn ≤ count < --critical`
is yellow, `count ≥ --critical` is red. A git error shows a ⚠️ instead.

### Markdown preview

`--viewmd-path` must point at an installed [viewmd](https://github.com/mo6/viewmd)
launcher (`viewmd.sh`, with its virtualenv set up per viewmd's README). Gitgleam
runs it per file to render formatted Markdown — including Mermaid diagrams as
ASCII art — for the Preview toggle. If viewmd is missing or errors, Preview
falls back to the colored diff, so the flag is safe to leave set.

Gitgleam also marks the blocks that changed so viewmd can highlight them; this
needs a viewmd that understands the `viewmd:mark` markers (viewmd issue
VIEWMD-0104). Until then the markers are invisible and Preview simply shows the
formatted file without change highlighting.

```bash
.build/release/Gitgleam --path ~/notes --label Notes \
    --viewmd-path ~/Projects/viewmd/viewmd.sh
```

`swift run` keeps the launching terminal occupied. For everyday use — and to
launch at login — build an optimized binary once and run that:

```bash
swift build -c release                          # produces .build/release/Gitgleam
.build/release/Gitgleam --path ~/code/my-repo   # launch it
```

## Run multiple instances

Gitgleam is a plain executable, so launching it more than once just starts
independent processes — each gets its own menu-bar item. Give each a distinct
`--label` so you can tell them apart:

```bash
.build/release/Gitgleam --path ~/code/api    --label "API" &
.build/release/Gitgleam --path ~/notes       --label "Notes" --critical 25 &
```

## Start automatically at login

Because this is a Swift Package (not a bundled `.app`), macOS's built-in
"Open at Login" list can't manage it directly. Instead, register the release
binary as a **LaunchAgent** — a small plist that `launchd` starts for you each
time you log in. For multiple instances, create one plist per instance with a
unique `Label`.

1. **Build the release binary** (once, and again after any code change):

   ```bash
   swift build -c release
   ```

   This creates `.build/release/Gitgleam` inside the project folder.
   Keep the generated `Gitgleam_Gitgleam.bundle` (localized strings) next to the
   binary — moving the binary alone drops the translations.

2. **Create the LaunchAgent** at
   `~/Library/LaunchAgents/nl.mo6.gitgleam.work.plist`. The `Label` and
   filename must be unique per instance; the flags go in `ProgramArguments`.
   launchd does **not** expand `~`, so use absolute paths and replace
   `/Users/you` with your home directory:

   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
     "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>Label</key>
       <string>nl.mo6.gitgleam.work</string>

       <key>ProgramArguments</key>
       <array>
           <string>/Users/you/Projects/Gitgleam/.build/release/Gitgleam</string>
           <string>--path</string>
           <string>/Users/you/code/my-repo</string>
           <string>--label</string>
           <string>Work</string>
       </array>

       <!-- Start at login and keep it running. -->
       <key>RunAtLoad</key>
       <true/>
       <key>KeepAlive</key>
       <true/>

       <!-- Logs, handy while getting it working. -->
       <key>StandardOutPath</key>
       <string>/tmp/gitgleam.work.out.log</string>
       <key>StandardErrorPath</key>
       <string>/tmp/gitgleam.work.err.log</string>
   </dict>
   </plist>
   ```

3. **Load it** (starts it now and enables it at every login):

   ```bash
   launchctl load ~/Library/LaunchAgents/nl.mo6.gitgleam.work.plist
   ```

   The menu bar icon should appear within a second or two.

### Managing the LaunchAgent

```bash
# Stop it and disable auto-start
launchctl unload ~/Library/LaunchAgents/nl.mo6.gitgleam.work.plist

# Restart after rebuilding the binary
launchctl unload ~/Library/LaunchAgents/nl.mo6.gitgleam.work.plist
launchctl load   ~/Library/LaunchAgents/nl.mo6.gitgleam.work.plist

# Check whether launchd considers it running (look for the Label in the list)
launchctl list | grep gitgleam
```

If it doesn't appear, check `/tmp/gitgleam.work.err.log` for errors.

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
swift run Gitgleam --path ~/repo -AppleLanguages '(nl)'
```

See [CLAUDE.md](CLAUDE.md) for architecture and development notes.
