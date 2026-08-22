import Foundation
import Combine
import AppKit

/// Tracks the uncommitted changes of the watched repository.
///
/// `@MainActor` because the UI (`@Published`) may only be updated on the main
/// thread. The actual git work runs in `Git`, off the main actor, so the UI
/// never blocks.
@MainActor
final class GitMonitor: ObservableObject {
    /// The changed files from the latest status check.
    @Published var changes: [FileChange] = []

    /// Error message if the git check failed, otherwise `nil`.
    @Published var errorMessage: String?

    /// The most recent commits, for the "Recent commits" submenu.
    @Published var commits: [Commit] = []

    /// Severity of the status. Drives the menu-bar icon and its color.
    enum Status {
        case error // git check failed: warning
        case clean // below the warn threshold: green
        case few   // at/above warn, below critical: yellow
        case many  // at/above critical: red
    }

    /// The current severity. An error takes priority over the change count.
    /// The yellow/red boundaries come from the live (Settings-editable)
    /// thresholds.
    var status: Status {
        if errorMessage != nil { return .error }
        let count = changes.count
        if count >= settings.criticalThreshold { return .many }
        if count >= settings.warnThreshold { return .few }
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

    /// The path being watched (fixed for this instance's lifetime — set via
    /// `--path`, not editable in Settings).
    private let path: String
    /// Live, user-editable defaults (thresholds, refresh interval, commit
    /// count, …). Changing these applies immediately: see the `Combine`
    /// subscriptions set up in `init`.
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
    private var menuIsOpen = false

    init(config: AppConfig, settings: Settings) {
        self.path = config.path
        self.settings = settings
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: settings.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        // Instant refresh on any change under the watched path.
        watcher = RepoWatcher(path: config.path) { [weak self] in
            Task { @MainActor in self?.refresh() }
        }

        // Pause refreshing while one of the app's own menus is open — see
        // `menuIsOpen`. AppKit posts these in-process for any `NSMenu` in this
        // app, which for this app means only the menu-bar dropdown and its
        // "Recent commits" submenu. The block-based API (rather than
        // target/selector) is used because `GitMonitor` isn't an `NSObject`.
        NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.menuOpened() } }
        NotificationCenter.default.addObserver(
            forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.menuClosed() } }

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

    /// Called when one of the app's own menus opens/closes (see `menuIsOpen`).
    /// Closing catches up on anything that arrived while it was open.
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
}
