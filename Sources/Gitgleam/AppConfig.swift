import Foundation

/// Runtime configuration, parsed from command-line flags at launch.
///
/// Passing different values lets you run several instances side by side, each
/// watching its own repository with its own label and color thresholds.
struct AppConfig {
    /// Repository/directory to watch.
    let path: String
    /// Optional text shown before the menu-bar indicator (nil = none).
    let label: String?
    /// Change count at or above which the icon turns yellow.
    let warnThreshold: Int
    /// Change count at or above which the icon turns red.
    let criticalThreshold: Int
    /// How often to re-check the repository, in seconds.
    let refreshInterval: TimeInterval
    /// Largest number of file rows the dropdown menu shows before overflowing
    /// into the "Show all changes" window.
    let maxEntries: Int
    /// Number of recent commits listed in the "Recent commits" submenu.
    let commits: Int
    /// Path to the `viewmd.sh` launcher used to render Markdown previews, or
    /// nil when preview is disabled (no `--viewmd-path` given).
    let viewmdPath: String?
    /// Which view a Markdown window opens in, when preview is available. Nil
    /// means "preview" (the default once viewmd is configured).
    let defaultView: ViewMode?
    /// Render width (columns) passed to viewmd for previews.
    let previewWidth: Int

    /// Everything a view needs to render (and default to) a Markdown preview.
    /// Nil when preview is unavailable, so a nil value means "diff only".
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

    /// Preview settings for the windows, or nil when `--viewmd-path` is unset.
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
    /// Menu entry cap used when `--max-entries` is not given.
    static let defaultMaxEntries = 25
    /// Commit count used when `--commits` is not given.
    static let defaultCommits = 10
    /// Preview render width used when `--preview-width` is not given.
    static let defaultPreviewWidth = 100

    /// Parses the flags: `--path/-p`, `--label/-l`, `--warn/-w`, `--critical/-c`,
    /// `--interval/-i`, `--max-entries/-m`, `--commits/-C`, `--help/-h`. Unknown
    /// flags are ignored; `--help` prints usage and exits.
    static func parse(_ arguments: [String]) -> AppConfig {
        var path: String?
        var label: String?
        var warn = defaultWarnThreshold
        var critical = defaultCriticalThreshold
        var interval = defaultInterval
        var maxEntries = defaultMaxEntries
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
            case "--max-entries", "-m":
                if let raw = value(after: &i), let n = Int(raw) { maxEntries = n }
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

        // Resolve the path: expand a leading ~, default to the current directory.
        let resolvedPath = path.map { ($0 as NSString).expandingTildeInPath }
            ?? FileManager.default.currentDirectoryPath

        // Keep thresholds sane: at least 1, and warn no higher than critical.
        warn = max(1, warn)
        critical = max(warn, critical)

        // Clamp the refresh interval to the allowed range.
        interval = min(maxInterval, max(minInterval, interval))

        // Show at least one entry before overflowing.
        maxEntries = max(1, maxEntries)

        // List at least one commit in the submenu.
        commits = max(1, commits)

        // Expand a leading ~ in the viewmd path; keep at least a usable width.
        let resolvedViewmdPath = (viewmdPath?.isEmpty == false)
            ? (viewmdPath! as NSString).expandingTildeInPath
            : nil
        previewWidth = max(20, previewWidth)

        return AppConfig(
            path: resolvedPath,
            label: (label?.isEmpty == false) ? label : nil,
            warnThreshold: warn,
            criticalThreshold: critical,
            refreshInterval: interval,
            maxEntries: maxEntries,
            commits: commits,
            viewmdPath: resolvedViewmdPath,
            defaultView: defaultView,
            previewWidth: previewWidth
        )
    }

    private static func printUsage() {
        print("""
        Gitgleam — a menu-bar git status watcher.

        Usage: Gitgleam [options]

        Options:
          -p, --path <dir>       Repository to watch (default: current directory)
          -l, --label <text>     Text shown before the menu-bar indicator
          -w, --warn <n>         Change count at/above which the icon is yellow (default: 1)
          -c, --critical <n>     Change count at/above which the icon is red (default: 10)
          -i, --interval <secs>  Safety-net poll interval; a filesystem watcher
                                 refreshes instantly (default: 60, min: 10, max: 300)
          -m, --max-entries <n>  Max file rows in the menu before overflow (default: 25)
          -C, --commits <n>      Recent commits listed in the submenu (default: 10)
          -V, --viewmd-path <p>  Path to viewmd.sh; enables the Markdown Preview toggle
              --default-view <v> Initial view for a Markdown file: diff | preview
                                 (default: preview, when --viewmd-path is set)
              --preview-width <n> Columns passed to viewmd for previews (default: 100)
          -h, --help             Show this help and exit

        Run multiple instances with different --path/--label to watch several repos.
        With --viewmd-path set, Markdown files gain a Diff/Preview toggle (Preview
        renders formatted Markdown, including Mermaid diagrams, via viewmd).
        """)
    }
}
