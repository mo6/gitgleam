import Foundation

/// User-editable defaults, shown and changed in the Settings window.
///
/// Seeded once from the CLI-parsed `AppConfig` (so the existing `--warn`,
/// `--viewmd-path`, etc. flags remain the *first-launch* defaults), then
/// persisted independently via `UserDefaults`, keyed by the watched path so
/// multiple instances (each launched with a different `--path`) keep separate
/// settings. Every property applies live: `GitMonitor` and any newly opened
/// diff/commit window read the current values, no restart needed.
@MainActor
final class Settings: ObservableObject {
    @Published var warnThreshold: Int {
        didSet {
            let clamped = max(1, warnThreshold)
            guard clamped == warnThreshold else { warnThreshold = clamped; return }
            save()
        }
    }
    @Published var criticalThreshold: Int {
        didSet {
            let clamped = max(1, criticalThreshold)
            guard clamped == criticalThreshold else { criticalThreshold = clamped; return }
            save()
        }
    }
    @Published var refreshInterval: TimeInterval {
        didSet {
            let clamped = min(AppConfig.maxInterval, max(AppConfig.minInterval, refreshInterval))
            guard clamped == refreshInterval else { refreshInterval = clamped; return }
            save()
        }
    }
    @Published var maxEntries: Int {
        didSet {
            let clamped = max(1, maxEntries)
            guard clamped == maxEntries else { maxEntries = clamped; return }
            save()
        }
    }
    @Published var commits: Int {
        didSet {
            let clamped = max(1, commits)
            guard clamped == commits else { commits = clamped; return }
            save()
        }
    }
    /// Path to `viewmd.sh`, or empty to disable Markdown preview.
    @Published var viewmdPath: String { didSet { save() } }
    @Published var defaultView: ViewMode { didSet { save() } }
    @Published var previewWidth: Int {
        didSet {
            let clamped = max(20, previewWidth)
            guard clamped == previewWidth else { previewWidth = clamped; return }
            save()
        }
    }
    /// When true, Markdown preview renders leave their input file in `/tmp/`
    /// for inspection instead of deleting it — see `Viewmd.render`.
    @Published var debugKeepPreviewFiles: Bool { didSet { save() } }

    /// Preview settings for the diff/commit windows, or nil when no viewmd
    /// path is set (diff-only). Mirrors `AppConfig.previewSettings`, but
    /// reflects the live, editable values.
    var previewSettings: AppConfig.PreviewSettings? {
        let path = viewmdPath.trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return nil }
        return AppConfig.PreviewSettings(
            viewmdPath: path, width: previewWidth, defaultView: defaultView,
            debugKeepFiles: debugKeepPreviewFiles
        )
    }

    private let defaults: UserDefaults
    private let storageKey: String

    init(config: AppConfig, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.storageKey = "nl.mo6.gitgleam.settings.\(config.path)"

        let stored = defaults.data(forKey: storageKey).flatMap {
            try? JSONDecoder().decode(StoredSettings.self, from: $0)
        }

        // Assignments in this initializer don't trigger the `didSet` clamps
        // above (Swift skips property observers for a property's own
        // initializer), so no explicit re-entrancy guard is needed here.
        warnThreshold = stored?.warnThreshold ?? config.warnThreshold
        criticalThreshold = stored?.criticalThreshold ?? config.criticalThreshold
        refreshInterval = stored?.refreshInterval ?? config.refreshInterval
        maxEntries = stored?.maxEntries ?? config.maxEntries
        commits = stored?.commits ?? config.commits
        viewmdPath = stored?.viewmdPath ?? (config.viewmdPath ?? "")
        defaultView = stored?.defaultView ?? (config.defaultView ?? .preview)
        previewWidth = stored?.previewWidth ?? config.previewWidth
        debugKeepPreviewFiles = stored?.debugKeepPreviewFiles ?? false
    }

    /// The on-disk shape, versioned implicitly by field presence: a decode
    /// failure (e.g. a future field added later) is treated as "no stored
    /// settings" rather than a crash, via `try?` at the call site.
    private struct StoredSettings: Codable {
        var warnThreshold: Int
        var criticalThreshold: Int
        var refreshInterval: TimeInterval
        var maxEntries: Int
        var commits: Int
        var viewmdPath: String
        var defaultView: ViewMode
        var previewWidth: Int
        var debugKeepPreviewFiles: Bool
    }

    private func save() {
        let stored = StoredSettings(
            warnThreshold: warnThreshold, criticalThreshold: criticalThreshold,
            refreshInterval: refreshInterval, maxEntries: maxEntries, commits: commits,
            viewmdPath: viewmdPath, defaultView: defaultView, previewWidth: previewWidth,
            debugKeepPreviewFiles: debugKeepPreviewFiles
        )
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
