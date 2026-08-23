import Foundation
import Combine
import AppKit

/// Owns one `RepoMonitor` per repository in `settings.repos` and aggregates
/// them into the single menu-bar indicator.
///
/// `settings.repos` is the source of truth for *which* repos exist; this
/// class only keeps `monitors` in sync with the enabled ones (creating a
/// `RepoMonitor` for a newly enabled entry, tearing one down when its entry
/// is removed or paused, and recreating one when its path changes — the
/// watcher and cached state are path-bound). A label-only edit doesn't need
/// a new monitor.
@MainActor
final class AppMonitor: ObservableObject {
    @Published private(set) var monitors: [UUID: RepoMonitor] = [:]

    private let settings: Settings
    /// The `RepoConfig.path` each monitor was built with, so a path edit
    /// (same id, different path) can be told apart from a label-only edit.
    private var monitoredPaths: [UUID: String] = [:]
    private var forwarders: [UUID: AnyCancellable] = [:]
    private var cancellables = Set<AnyCancellable>()

    init(settings: Settings) {
        self.settings = settings
        rebuildMonitors(for: settings.repos)

        settings.$repos
            .dropFirst()
            .sink { [weak self] repos in self?.rebuildMonitors(for: repos) }
            .store(in: &cancellables)

        // Pause every repo's refresh while one of the app's own menus is
        // open — see `RepoMonitor.menuIsOpen`. AppKit posts these in-process
        // for any `NSMenu` in this app (the menu-bar dropdown and its
        // submenus). One pair of observers here, shared by every repo,
        // rather than each `RepoMonitor` registering its own.
        NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.monitors.values.forEach { $0.menuOpened() } } }
        NotificationCenter.default.addObserver(
            forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.monitors.values.forEach { $0.menuClosed() } } }
    }

    /// Repos in `settings.repos` order. Disabled repos have `monitor == nil`
    /// (they stay in the menu as paused rows; nothing is watching them).
    var orderedEntries: [(repo: RepoConfig, monitor: RepoMonitor?)] {
        settings.repos.map { repo in (repo, monitors[repo.id]) }
    }

    /// Enabled repos in display order, each paired with its live monitor.
    var orderedMonitors: [(repo: RepoConfig, monitor: RepoMonitor)] {
        orderedEntries.compactMap { entry in
            guard let monitor = entry.monitor else { return nil }
            return (entry.repo, monitor)
        }
    }

    /// Sum of every repo's change count.
    var aggregateChangeCount: Int {
        monitors.values.reduce(0) { $0 + $1.changes.count }
    }

    /// The aggregate severity: an error in any repo takes priority, otherwise
    /// the same warn/critical comparison `RepoMonitor.status` uses, applied
    /// to the summed count.
    var aggregateStatus: RepoMonitor.Status {
        if monitors.values.contains(where: { $0.errorMessage != nil }) { return .error }
        let count = aggregateChangeCount
        if count >= settings.criticalThreshold { return .many }
        if count >= settings.warnThreshold { return .few }
        return .clean
    }

    /// Refreshes every repo (the menu's Refresh button).
    func refreshAll() {
        monitors.values.forEach { $0.refresh() }
    }

    private func rebuildMonitors(for repos: [RepoConfig]) {
        // Remove monitors for repos that no longer exist, or that were paused.
        let activeIDs = Set(repos.filter(\.isEnabled).map(\.id))
        for id in monitors.keys where !activeIDs.contains(id) {
            monitors.removeValue(forKey: id)?.stop()
            monitoredPaths.removeValue(forKey: id)
            forwarders.removeValue(forKey: id)
        }

        // Add/recreate monitors for newly enabled repos, or ones whose path changed.
        for repo in repos where repo.isEnabled {
            if let existingPath = monitoredPaths[repo.id], existingPath == repo.path {
                continue // unchanged (or label-only edit): keep the running monitor
            }
            monitors[repo.id]?.stop()
            let monitor = RepoMonitor(repo: repo, settings: settings)
            monitors[repo.id] = monitor
            monitoredPaths[repo.id] = repo.path
            forwarders[repo.id] = monitor.objectWillChange
                .sink { [weak self] _ in self?.objectWillChange.send() }
        }
    }
}
