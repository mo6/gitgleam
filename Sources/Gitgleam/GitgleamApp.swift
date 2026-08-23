import SwiftUI

/// App entry point. The UI lives entirely in the menu bar via `MenuBarExtra`;
/// the diff `WindowGroup` opens on demand when a file is clicked.
@main
struct GitgleamApp: App {
    // Attaches an AppDelegate so we can hide the Dock icon.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Parsed once at launch from the command-line flags.
    static let config = AppConfig.parse(CommandLine.arguments)

    /// Live, user-editable defaults shown in the Settings window — seeded
    /// from the CLI flags, then persisted independently.
    @StateObject private var settings: Settings
    // The observable that tracks every repo's git status and aggregates them
    // for the menu-bar indicator, kept in sync with `settings` (repo list,
    // thresholds, refresh interval, …).
    @StateObject private var monitor: AppMonitor

    init() {
        // `settings` is built once here (rather than as a plain property
        // default value) so `monitor` can be constructed with the same
        // instance — a property's default-value expression can't reference
        // another property, so the wiring has to happen in `init`.
        let settings = Settings(config: Self.config)
        _settings = StateObject(wrappedValue: settings)
        _monitor = StateObject(wrappedValue: AppMonitor(settings: settings))
    }

    var body: some Scene {
        MenuBarExtra {
            // Dropdown menu content.
            MenuContent(monitor: monitor)
        } label: {
            // Menu-bar label: the aggregate status icon + count across every
            // configured repo.
            //
            // This MUST be a single `Text`: a `MenuBarExtra` `.menu` label with
            // several sibling views is coerced into an icon+title layout that
            // reorders the icon ahead of the text and drops the extra views. A
            // single `Text` preserves the order (icon, count) and every part.
            // We use a colored circle emoji for the icon because an `Image`
            // interpolated into `Text` is tinted as a monochrome template in
            // the menu bar, which loses the severity color.
            switch monitor.aggregateStatus {
            case .error:
                // On a git error in any repo we show a warning emoji instead
                // of a count.
                Text("⚠️")
            default:
                Text("\(Self.statusIcon(for: monitor.aggregateStatus)) \(monitor.aggregateChangeCount)")
            }
        }
        .menuBarExtraStyle(.menu)

        // Diff window: one per file, opened from the menu with the chosen
        // `RepoFileChange` as its value (bundles which repo the file
        // belongs to, now that several repos can be open at once).
        WindowGroup(id: "diff", for: RepoFileChange.self) { $entry in
            if let entry {
                DiffView(change: entry.change, repoPath: entry.repoPath, preview: settings.previewSettings)
                    .navigationTitle(entry.change.path)
            }
        }
        .windowResizability(.contentSize)

        // Commit-detail window: one per commit, opened from the "Recent commits"
        // submenu with the chosen `RepoCommit` as its value.
        WindowGroup(id: "commit", for: RepoCommit.self) { $entry in
            if let entry {
                CommitDetailView(commit: entry.commit, repoPath: entry.repoPath, preview: settings.previewSettings)
                    .navigationTitle(entry.commit.shortSHA)
            }
        }
        .windowResizability(.contentSize)

        // Full-list window: showing every change for one repo when its menu
        // cap overflows, keyed by repo id. It reads live from `monitor`/
        // `settings`, so it updates as the repo changes (or is edited/removed).
        WindowGroup(L10n.allChanges, id: "all", for: UUID.self) { $repoID in
            if let repoID, let repoMonitor = monitor.monitors[repoID],
               let repo = settings.repos.first(where: { $0.id == repoID }) {
                AllChangesView(monitor: repoMonitor, repo: repo)
                    .navigationTitle(repo.label)
            } else {
                Text(L10n.repositoryRemoved)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 420, minHeight: 480)
            }
        }

        // Settings window: a single reused window for editing the live
        // defaults (repos, thresholds, refresh interval, viewmd path, …).
        Window(L10n.settings, id: "settings") {
            SettingsView(settings: settings)
        }
        .windowResizability(.contentSize)
    }

    /// The colored circle emoji shown in the menu bar for a given severity.
    ///
    /// Emoji keep their color in the menu-bar label (unlike a template-tinted
    /// `Image`), so the green/yellow/red severity stays visible.
    private static func statusIcon(for status: RepoMonitor.Status) -> String {
        switch status {
        case .error: return "⚠️"  // shown via the `.error` case, not here
        case .clean: return "🟢"
        case .few:   return "🟡"
        case .many:  return "🔴"
        }
    }
}

/// Hides the Dock icon so this is a pure menu-bar app. Replaces the
/// `LSUIElement` Info.plist key, which a Swift Package does not have.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
