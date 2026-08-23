import Foundation
import Combine

/// Tracks the uncommitted changes of one watched repository.
///
/// `@MainActor` because the UI (`@Published`) may only be updated on the main
/// thread. The actual git work runs in `Git`, off the main actor, so the UI
/// never blocks. Owned by `AppMonitor`, one per `RepoConfig` in
/// `settings.repos`.
@MainActor
final class RepoMonitor: ObservableObject {
    /// The changed files from the latest status check.
    @Published var changes: [FileChange] = []

    /// Error message if the git check failed, otherwise `nil`.
    @Published var errorMessage: String?

    /// The most recent commits, for the "Recent commits" submenu.
    @Published var commits: [Commit] = []

    /// Severity of the status. Drives this repo's submenu icon and the
    /// menu-bar aggregate (via `AppMonitor`).
    enum Status {
        case error // git check failed: warning
        case clean // below the warn threshold: green
        case few   // at/above warn, below critical: yellow
        case many  // at/above critical: red
    }

    /// The current severity. An error takes priority over the change count.
    /// The yellow/red boundaries come from this repo's override if set,
    /// otherwise the live global Settings thresholds.
    var status: Status {
        if errorMessage != nil { return .error }
        let count = changes.count
        if count >= criticalThreshold { return .many }
        if count >= warnThreshold { return .few }
        return .clean
    }

    /// The changes grouped for the menu sections.
    var changedFiles: [FileChange] { changes.filter { $0.category == .changed } }
    var newFiles: [FileChange] { changes.filter { $0.category == .new } }
    var deletedFiles: [FileChange] { changes.filter { $0.category == .deleted } }

    /// Largest number of file rows the dropdown menu shows before overflowing
    /// into the "Show all changes" window. Exposes the live setting without
    /// widening access to the whole `Settings` object.
    var maxMenuEntries: Int { settings.maxEntries }

    /// The path being watched (fixed for this monitor's lifetime — `AppMonitor`
    /// recreates the monitor if the repo's path is edited in Settings).
    private let path: String
    /// Stable id so live threshold overrides can be read from `settings.repos`
    /// without recreating the monitor.
    private let repoID: UUID
    /// Live, user-editable defaults (thresholds, refresh interval, commit
    /// count, …), shared across every repo. Changing these applies
    /// immediately: see the `Combine` subscriptions set up in `init`.
    private let settings: Settings

    private var timer: Timer?
    /// Filesystem watcher that refreshes the instant the repo changes. The
    /// timer above is a periodic safety net for anything it misses.
    private var watcher: RepoWatcher?
    private var cancellables = Set<AnyCancellable>()

    /// True while a refresh is running, so overlapping triggers (timer +
    /// watcher, or a burst of events) don't stack. `pendingRefresh` records a
    /// trigger that arrived mid-refresh so it runs once more afterwards — this
    /// guarantees a change is never dropped and also damps any `git status` →
    /// `.git/index` → event feedback into a single follow-up. It does double
    /// duty for `menuIsOpen` below, for the same reason.
    private var refreshInFlight = false
    private var pendingRefresh = false

    /// True while one of the app's own menus (the menu-bar dropdown, or a
    /// submenu/context menu within it) is open. A refresh while a menu is
    /// open — even one that changes nothing visible — rebuilds the menu and
    /// dismisses any open submenu (e.g. "Recent commits" closing the instant
    /// it opens), so refreshes are deferred until the menu closes instead.
    /// Toggled by `AppMonitor` (which owns the single pair of `NSMenu`
    /// notification observers shared by every repo) via `menuOpened()`/
    /// `menuClosed()`.
    private var menuIsOpen = false

    init(repo: RepoConfig, settings: Settings) {
        self.path = repo.path
        self.repoID = repo.id
        self.settings = settings
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: settings.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        // Instant refresh on any change under the watched path.
        watcher = RepoWatcher(path: repo.path) { [weak self] in
            Task { @MainActor in self?.refresh() }
        }

        // `status`/`maxMenuEntries` read `settings` directly, but they're
        // plain computed properties: a `Settings`-only change wouldn't
        // otherwise tell SwiftUI views observing `self` to re-render, so
        // forward it. `commits`/`refreshInterval` additionally need an
        // actual re-fetch/re-schedule, not just a re-render.
        settings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        settings.$commits
            .dropFirst()
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
        settings.$refreshInterval
            .dropFirst()
            .sink { [weak self] interval in self?.rescheduleTimer(interval) }
            .store(in: &cancellables)
    }

    /// Warn/critical for this repo: an override on `RepoConfig` if set,
    /// otherwise the global Settings values. Critical is never below warn.
    private var warnThreshold: Int {
        max(1, settings.repos.first { $0.id == repoID }?.warnThreshold ?? settings.warnThreshold)
    }

    private var criticalThreshold: Int {
        max(warnThreshold, settings.repos.first { $0.id == repoID }?.criticalThreshold ?? settings.criticalThreshold)
    }

    private func rescheduleTimer(_ interval: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    /// Starts a git status check and refreshes the recent-commit list, updating
    /// `changes`/`errorMessage`/`commits` when done. Coalesced: a trigger that
    /// arrives while a refresh is in flight schedules exactly one more run.
    ///
    /// Each `@Published` property is only reassigned when its value actually
    /// changed. The filesystem watcher fires on any change under the whole
    /// tree — including `.git`, which `git status` itself touches — so most
    /// refreshes find nothing different. An unconditional reassignment would
    /// still fire `objectWillChange` and rebuild the menu on every one of
    /// those no-op refreshes, which was closing the "Recent commits" submenu
    /// the instant it opened.
    func refresh() {
        guard !refreshInFlight else { pendingRefresh = true; return }
        guard !menuIsOpen else { pendingRefresh = true; return }
        refreshInFlight = true

        let path = self.path
        let commitLimit = settings.commits
        Task {
            // Kick off both reads together, but apply the status first so the
            // menu-bar icon is never held up by the history read.
            async let commitList = Git.recentCommits(limit: commitLimit, at: path)
            switch await Git.status(at: path) {
            case .success(let changes):
                if self.changes != changes { self.changes = changes }
                if self.errorMessage != nil { self.errorMessage = nil }
            case .failure(let message):
                if !self.changes.isEmpty { self.changes = [] }
                if self.errorMessage != message { self.errorMessage = message }
            }
            let commits = await commitList
            if self.commits != commits { self.commits = commits }

            refreshInFlight = false
            if pendingRefresh {
                pendingRefresh = false
                refresh()
            }
        }
    }

    /// Called by `AppMonitor` when one of the app's own menus opens/closes
    /// (see `menuIsOpen`). Closing catches up on anything that arrived while
    /// it was open.
    func menuOpened() {
        menuIsOpen = true
    }

    func menuClosed() {
        menuIsOpen = false
        if pendingRefresh {
            pendingRefresh = false
            refresh()
        }
    }

    /// Drops the timer and FSEvents watcher. Called by `AppMonitor` before
    /// discarding this monitor (repo removed, paused, or path changed).
    func stop() {
        timer?.invalidate()
        timer = nil
        watcher = nil
    }
}
