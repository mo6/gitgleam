import Foundation

/// User-editable defaults, shown and changed in the Settings window.
///
/// Seeded once from the CLI-parsed `AppConfig` (so the existing `--warn`,
/// `--viewmd-path`, `--repo`, etc. flags remain the *first-launch* defaults),
/// then persisted independently via `UserDefaults` under one global key.
/// Every property applies live: `AppMonitor`/`RepoMonitor` and any newly
/// opened diff/commit window read the current values, no restart needed.
@MainActor
final class Settings: ObservableObject {
    /// The watched repositories, in display order. Managed live from
    /// Settings' Repositories tab; `AppMonitor` creates/destroys a
    /// `RepoMonitor` for each entry.
    @Published var repos: [RepoConfig] { didSet { save() } }
    /// A language code (e.g. `"nl"`) from `L10n.availableLanguages`, or
    /// `"auto"` to follow the system language. Not seeded from `AppConfig` —
    /// there's no CLI flag for it, so "auto" is always the first-launch
    /// default.
    @Published var language: String {
        didSet {
            L10n.languageOverride = (language == "auto") ? nil : language
            save()
        }
    }
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

    /// Fixed, global storage key. Before multi-repo support this was keyed
    /// per watched path (`"nl.mo6.gitgleam.settings.\(path)"`) since each
    /// process watched exactly one repo; now one process holds the whole
    /// repo list, so there's a single blob. `init` migrates an existing
    /// per-path blob the first time it finds nothing under this key — see
    /// below.
    static let storageKey = "nl.mo6.gitgleam.settings"

    private let defaults: UserDefaults

    init(config: AppConfig, defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let stored = defaults.data(forKey: Settings.storageKey).flatMap {
            try? JSONDecoder().decode(StoredSettings.self, from: $0)
        }
        // Nothing under the new global key yet: migrate a legacy per-path
        // blob if this launch's first repo matches one (i.e. this is an
        // existing single-repo install upgrading in place). Only the
        // thresholds/etc. are adopted from it; the repo list itself always
        // comes from `config.initialRepos` below.
        let legacy = stored == nil ? config.initialRepos.first.flatMap { first in
            defaults.data(forKey: "nl.mo6.gitgleam.settings.\(first.path)").flatMap {
                try? JSONDecoder().decode(StoredSettings.self, from: $0)
            }
        } : nil
        let seed = stored ?? legacy

        // Assignments in this initializer don't trigger the `didSet` clamps
        // above (Swift skips property observers for a property's own
        // initializer), so no explicit re-entrancy guard is needed here.
        repos = seed?.repos ?? config.initialRepos
        language = seed?.language ?? "auto"
        warnThreshold = seed?.warnThreshold ?? config.warnThreshold
        criticalThreshold = seed?.criticalThreshold ?? config.criticalThreshold
        refreshInterval = seed?.refreshInterval ?? config.refreshInterval
        maxEntries = seed?.maxEntries ?? config.maxEntries
        commits = seed?.commits ?? config.commits
        viewmdPath = seed?.viewmdPath ?? (config.viewmdPath ?? "")
        defaultView = seed?.defaultView ?? (config.defaultView ?? .preview)
        previewWidth = seed?.previewWidth ?? config.previewWidth
        debugKeepPreviewFiles = seed?.debugKeepPreviewFiles ?? false

        // `language`'s own didSet (which applies the override) doesn't fire
        // for this initializer's assignment above, so apply it explicitly.
        L10n.languageOverride = (language == "auto") ? nil : language

        if stored == nil { save() }
    }

    /// The on-disk shape, versioned implicitly by field presence: a decode
    /// failure (e.g. a future field added later) is treated as "no stored
    /// settings" rather than a crash, via `try?` at the call site.
    private struct StoredSettings: Codable {
        /// Optional (rather than required, like the rest of these fields) so
        /// settings persisted before this field existed still decode — a
        /// missing key becomes `nil` instead of failing the whole decode.
        var language: String?
        /// Optional for the same reason: absent from every legacy per-path
        /// blob (multi-repo didn't exist yet), and from any future field
        /// added the same way.
        var repos: [RepoConfig]?
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
            language: language, repos: repos, warnThreshold: warnThreshold, criticalThreshold: criticalThreshold,
            refreshInterval: refreshInterval, maxEntries: maxEntries, commits: commits,
            viewmdPath: viewmdPath, defaultView: defaultView, previewWidth: previewWidth,
            debugKeepPreviewFiles: debugKeepPreviewFiles
        )
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: Settings.storageKey)
        }
    }
}
