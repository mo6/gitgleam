import Foundation

/// Runtime configuration, parsed from command-line flags at launch.
///
/// Only used to seed the very first launch's `Settings` — the repo list,
/// thresholds, and preview settings all become live-editable and persist
/// independently from then on (see `Settings`).
struct AppConfig {
    /// Repositories to watch at first launch, from repeatable `--repo`
    /// flags (or synthesized from a single `--path`/`--label`, for
    /// back-compat). Only used to seed `Settings.repos` the very first time
    /// the app runs — after that, the repo list is managed live in Settings
    /// and persisted independently.
    let initialRepos: [RepoConfig]
    /// Change count at or above which the icon turns yellow.
    let warnThreshold: Int
    /// Change count at or above which the icon turns red.
    let criticalThreshold: Int
    /// How often to re-check the repository, in seconds.
    let refreshInterval: TimeInterval
    /// Number of recent commits listed in the "Recent commits" submenu.
    let commits: Int
    /// Path to the `viewmd.sh` launcher used to render Markdown previews, or
    /// nil when the viewmd Preview toggle is off (no `--viewmd-path` given).
    /// The built-in Web preview does not need this.
    let viewmdPath: String?
    /// Which view a Markdown window opens in. Nil means "preview" (which
    /// falls back to Web when viewmd isn't configured).
    let defaultView: ViewMode?
    /// Render width (columns) passed to viewmd for previews.
    let previewWidth: Int

    /// Everything a view needs to render the viewmd Preview. Nil when no
    /// viewmd path is set — the built-in Web preview still works for Markdown.
    struct PreviewSettings {
        let viewmdPath: String
        let width: Int
        /// Resolved initial view for a Markdown file (preview unless overridden).
        let defaultView: ViewMode
        /// When true, `Viewmd.render` writes its input file to `/tmp/` and
        /// leaves it there for inspection, instead of a private, auto-cleaned
        /// temp file. Only ever set from the Settings window's debug toggle
        /// (see `Settings.previewSettings`); the CLI has no flag for it.
        let debugKeepFiles: Bool

        init(viewmdPath: String, width: Int, defaultView: ViewMode, debugKeepFiles: Bool = false) {
            self.viewmdPath = viewmdPath
            self.width = width
            self.defaultView = defaultView
            self.debugKeepFiles = debugKeepFiles
        }
    }

    /// viewmd settings for the windows, or nil when `--viewmd-path` is unset.
    /// Markdown still has the built-in Web preview without this.
    var previewSettings: PreviewSettings? {
        guard let viewmdPath else { return nil }
        return PreviewSettings(viewmdPath: viewmdPath, width: previewWidth, defaultView: defaultView ?? .preview)
    }

    /// Smallest and largest allowed refresh interval, in seconds.
    static let minInterval: TimeInterval = 10
    static let maxInterval: TimeInterval = 300
    /// Thresholds used when `--warn`/`--critical` are not given.
    static let defaultWarnThreshold = 1
    static let defaultCriticalThreshold = 10
    /// Refresh interval used when `--interval` is not given. This is a
    /// safety-net poll: a filesystem watcher (`RepoWatcher`) refreshes the
    /// instant the repo changes, so the periodic check only has to catch
    /// anything the watcher misses.
    static let defaultInterval: TimeInterval = 60
    /// Commit count used when `--commits` is not given.
    static let defaultCommits = 10
    /// Preview render width used when `--preview-width` is not given.
    static let defaultPreviewWidth = 100
    /// Soft warning in Settings when this many repos are configured — each
    /// one is a timer + FSEvents watcher + periodic `git status`.
    static let repoCountWarning = 8
    /// Hard cap: Add is disabled once the list reaches this many entries.
    static let repoCountCap = 20

    /// Parses the flags: `--repo/-r` (repeatable), `--path/-p`, `--label/-l`,
    /// `--warn/-w`, `--critical/-c`, `--interval/-i`, `--commits/-C`,
    /// `--help/-h`. Unknown flags are ignored; `--help` prints
    /// usage and exits.
    static func parse(_ arguments: [String]) -> AppConfig {
        var repoFlags: [String] = []
        var path: String?
        var label: String?
        var warn = defaultWarnThreshold
        var critical = defaultCriticalThreshold
        var interval = defaultInterval
        var commits = defaultCommits
        var viewmdPath: String?
        var defaultView: ViewMode?
        var previewWidth = defaultPreviewWidth

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
            case "--warn", "-w":
                if let raw = value(after: &i), let n = Int(raw) { warn = n }
            case "--critical", "-c":
                if let raw = value(after: &i), let n = Int(raw) { critical = n }
            case "--interval", "-i":
                if let raw = value(after: &i), let n = TimeInterval(raw) { interval = n }
            case "--commits", "-C":
                if let raw = value(after: &i), let n = Int(raw) { commits = n }
            case "--viewmd-path", "-V":
                viewmdPath = value(after: &i)
            case "--default-view":
                if let raw = value(after: &i) { defaultView = ViewMode(rawValue: raw.lowercased()) }
            case "--preview-width":
                if let raw = value(after: &i), let n = Int(raw) { previewWidth = n }
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

        // Keep thresholds sane: at least 1, and warn no higher than critical.
        warn = max(1, warn)
        critical = max(warn, critical)

        // Clamp the refresh interval to the allowed range.
        interval = min(maxInterval, max(minInterval, interval))

        // List at least one commit in the submenu.
        commits = max(1, commits)

        // Expand a leading ~ in the viewmd path; keep at least a usable width.
        let resolvedViewmdPath = (viewmdPath?.isEmpty == false)
            ? (viewmdPath! as NSString).expandingTildeInPath
            : nil
        previewWidth = max(20, previewWidth)

        return AppConfig(
            initialRepos: resolvedRepos,
            warnThreshold: warn,
            criticalThreshold: critical,
            refreshInterval: interval,
            commits: commits,
            viewmdPath: resolvedViewmdPath,
            defaultView: defaultView,
            previewWidth: previewWidth
        )
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
          -w, --warn <n>         Change count at/above which the icon is yellow (default: 1)
          -c, --critical <n>     Change count at/above which the icon is red (default: 10)
          -i, --interval <secs>  Safety-net poll interval; a filesystem watcher
                                 refreshes instantly (default: 60, min: 10, max: 300)
          -C, --commits <n>      Recent commits listed in the submenu (default: 10)
          -V, --viewmd-path <p>  Path to viewmd.sh; enables the viewmd Preview toggle
              --default-view <v> Initial view for a Markdown file: diff | preview | web
                                 (default: preview, which falls back to web
                                 without viewmd)
              --preview-width <n> Columns passed to viewmd for previews (default: 100)
          -h, --help             Show this help and exit

        These are only first-launch defaults: the repo list, thresholds, and
        preview settings are all editable live afterwards from Settings, and
        persist independently of these flags.
        Markdown files always gain a Diff/Web toggle (Web is a bundled HTML
        preview with Mermaid). With --viewmd-path set, a third Preview toggle
        renders via viewmd as ANSI.
        """)
    }
}
