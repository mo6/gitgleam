import Foundation

/// Runtime configuration, parsed from command-line flags at launch.
///
/// Only used to seed the very first launch's `Settings` — the repo list and
/// viewmd path are the only things worth setting before the app can show its
/// own UI (e.g. from a LaunchAgent plist, so the menu bar isn't empty on
/// first login). Everything else (thresholds, poll interval, commit count,
/// default view, preview width) starts at a fixed default and is tuned from
/// Settings instead — see `AGENTS.md` for why the rest of the flags this app
/// used to have were removed once Settings covered the same ground.
struct AppConfig {
    /// Repositories to watch at first launch, from repeatable `--repo`
    /// flags (or synthesized from a single `--path`/`--label`, for
    /// back-compat). Only used to seed `Settings.repos` the very first time
    /// the app runs — after that, the repo list is managed live in Settings
    /// and persisted independently.
    let initialRepos: [RepoConfig]
    /// Path to the `viewmd.sh` launcher used to render Markdown previews, or
    /// nil when the viewmd Preview toggle is off (no `--viewmd-path` given).
    /// The built-in Web preview does not need this.
    let viewmdPath: String?

    /// Everything a view needs to render the viewmd Preview. Nil when no
    /// viewmd path is set — the built-in Web preview still works for Markdown.
    struct PreviewSettings {
        let viewmdPath: String
        let width: Int
        /// Resolved initial view for a Markdown file (preview unless overridden).
        let defaultView: ViewMode
        /// When true, `Viewmd.render` writes its input file to `/tmp/` and
        /// leaves it there for inspection, instead of a private, auto-cleaned
        /// temp file. Only ever set from the Settings window's debug toggle;
        /// the CLI has no flag for it.
        let debugKeepFiles: Bool

        init(viewmdPath: String, width: Int, defaultView: ViewMode, debugKeepFiles: Bool = false) {
            self.viewmdPath = viewmdPath
            self.width = width
            self.defaultView = defaultView
            self.debugKeepFiles = debugKeepFiles
        }
    }

    /// Smallest and largest allowed refresh interval, in seconds.
    static let minInterval: TimeInterval = 10
    static let maxInterval: TimeInterval = 300
    /// Thresholds `Settings` seeds with when nothing is persisted yet.
    static let defaultWarnThreshold = 1
    static let defaultCriticalThreshold = 10
    /// Refresh interval `Settings` seeds with. This is a safety-net poll: a
    /// filesystem watcher (`RepoWatcher`) refreshes the instant the repo
    /// changes, so the periodic check only has to catch anything the
    /// watcher misses.
    static let defaultInterval: TimeInterval = 60
    /// Commit count `Settings` seeds with.
    static let defaultCommits = 10
    /// Preview render width `Settings` seeds with.
    static let defaultPreviewWidth = 100
    /// Soft warning in Settings when this many repos are configured — each
    /// one is a timer + FSEvents watcher + periodic `git status`.
    static let repoCountWarning = 8
    /// Hard cap: Add is disabled once the list reaches this many entries.
    static let repoCountCap = 20

    /// Parses the flags: `--repo/-r` (repeatable), `--path/-p`, `--label/-l`,
    /// `--viewmd-path/-V`, `--help/-h`. Unknown flags are ignored; `--help`
    /// prints usage and exits.
    static func parse(_ arguments: [String]) -> AppConfig {
        var repoFlags: [String] = []
        var path: String?
        var label: String?
        var viewmdPath: String?

        // Reads the value that follows a flag, advancing the index past it.
        func value(after index: inout Int) -> String? {
            guard index + 1 < arguments.count else { return nil }
            index += 1
            return arguments[index]
        }

        var i = 1 // arguments[0] is the executable path
        while i < arguments.count {
            switch arguments[i] {
            case "--help", "-h":
                printUsage()
                exit(0)
            case "--repo", "-r":
                if let raw = value(after: &i) { repoFlags.append(raw) }
            case "--path", "-p":
                path = value(after: &i)
            case "--label", "-l":
                label = value(after: &i)
            case "--viewmd-path", "-V":
                viewmdPath = value(after: &i)
            default:
                break
            }
            i += 1
        }

        // Build the initial repo list: prefer repeatable --repo flags; fall
        // back to a single repo from --path/--label (today's behavior) when
        // no --repo was given; otherwise one repo at the current directory.
        let resolvedRepos: [RepoConfig]
        if !repoFlags.isEmpty {
            resolvedRepos = repoFlags.map(parseRepoFlag)
        } else {
            let resolvedPath = path.map { ($0 as NSString).expandingTildeInPath }
                ?? FileManager.default.currentDirectoryPath
            let resolvedLabel = (label?.isEmpty == false) ? label! : (resolvedPath as NSString).lastPathComponent
            resolvedRepos = [RepoConfig(path: resolvedPath, label: resolvedLabel)]
        }

        // Expand a leading ~ in the viewmd path.
        let resolvedViewmdPath = (viewmdPath?.isEmpty == false)
            ? (viewmdPath! as NSString).expandingTildeInPath
            : nil

        return AppConfig(initialRepos: resolvedRepos, viewmdPath: resolvedViewmdPath)
    }

    /// Parses one `--repo` value of the form `<path>` or `<path>:<label>`,
    /// expanding a leading `~` in the path. Falls back to the path's last
    /// component when no label is given.
    private static func parseRepoFlag(_ raw: String) -> RepoConfig {
        let parts = raw.split(separator: ":", maxSplits: 1)
        let rawPath = String(parts[0])
        let path = (rawPath as NSString).expandingTildeInPath
        let label = parts.count > 1 && !parts[1].isEmpty
            ? String(parts[1])
            : (path as NSString).lastPathComponent
        return RepoConfig(path: path, label: label)
    }

    private static func printUsage() {
        print("""
        Gitgleam — a menu-bar git status watcher.

        Usage: Gitgleam [options]

        Options:
          -r, --repo <path>[:<label>]  Repository to watch, optionally labeled;
                                       repeat for several repos (default: current
                                       directory)
          -p, --path <dir>       Repository to watch (single-repo shorthand for
                                 --repo; ignored if --repo is given)
          -l, --label <text>     Label for the --path repo
          -V, --viewmd-path <p>  Path to viewmd.sh; enables the viewmd Preview toggle
          -h, --help             Show this help and exit

        These are only first-launch defaults: the repo list and viewmd path are
        editable live afterwards from Settings, and persist independently of
        these flags. Everything else — thresholds, poll interval, commit count,
        default view, preview width, language, and more — has no CLI flag at
        all; set it from Settings, opened from the menu-bar dropdown.
        Every file gains a Diff/Diff (full) toggle (Diff shows a few lines of
        context around each change; Diff (full) shows the whole file with
        changes colored in place). Markdown files additionally gain a Web
        toggle (a bundled HTML preview with Mermaid), plus a Preview toggle
        (renders via viewmd as ANSI) when --viewmd-path is set.
        """)
    }
}
