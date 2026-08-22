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
    // The observable that tracks git status, configured from the flags and
    // kept in sync with `settings` (thresholds, refresh interval, …).
    @StateObject private var monitor: GitMonitor

    init() {
        // `settings` is built once here (rather than as a plain property
        // default value) so `monitor` can be constructed with the same
        // instance — a property's default-value expression can't reference
        // another property, so the wiring has to happen in `init`.
        let settings = Settings(config: Self.config)
        _settings = StateObject(wrappedValue: settings)
        _monitor = StateObject(wrappedValue: GitMonitor(config: Self.config, settings: settings))
    }

    var body: some Scene {
        MenuBarExtra {
            // Dropdown menu content.
            MenuContent(monitor: monitor)
        } label: {
            // Menu-bar label: optional text prefix + status icon + count.
            //
            // This MUST be a single `Text`: a `MenuBarExtra` `.menu` label with
            // several sibling views is coerced into an icon+title layout that
            // reorders the icon ahead of the text and drops the extra views. A
            // single `Text` preserves the order (label, icon, count) and every
            // part. We use a colored circle emoji for the icon because an
            // `Image` interpolated into `Text` is tinted as a monochrome
            // template in the menu bar, which loses the severity color. The
            // trailing space after the label separates it from the icon.
            let prefix = Self.config.label.map { $0 + " " } ?? ""
            switch monitor.status {
            case .error:
                // On a git error we show a warning emoji instead of a count.
                Text("\(prefix)⚠️")
            default:
                Text("\(prefix)\(Self.statusIcon(for: monitor.status)) \(monitor.changes.count)")
            }
        }
        .menuBarExtraStyle(.menu)

        // Diff window: one per file, opened from the menu with the chosen
        // `FileChange` as its value.
        WindowGroup(id: "diff", for: FileChange.self) { $change in
            if let change {
                DiffView(change: change, repoPath: Self.config.path, preview: settings.previewSettings)
                    .navigationTitle(change.path)
            }
        }
        .windowResizability(.contentSize)

        // Commit-detail window: one per commit, opened from the "Recent commits"
        // submenu with the chosen `Commit` as its value.
        WindowGroup(id: "commit", for: Commit.self) { $commit in
            if let commit {
                CommitDetailView(commit: commit, repoPath: Self.config.path, preview: settings.previewSettings)
                    .navigationTitle(commit.shortSHA)
            }
        }
        .windowResizability(.contentSize)

        // Full-list window: a single reused window (hence `Window`, not
        // `WindowGroup`) showing every change when the menu cap overflows. It
        // shares the same `monitor` instance as the menu, so it updates live.
        Window(L10n.allChanges, id: "all") {
            AllChangesView(monitor: monitor, repoPath: Self.config.path)
        }

        // Settings window: a single reused window for editing the live
        // defaults (thresholds, refresh interval, viewmd path, …).
        Window(L10n.settings, id: "settings") {
            SettingsView(settings: settings)
        }
        .windowResizability(.contentSize)
    }

    /// The colored circle emoji shown in the menu bar for a given severity.
    ///
    /// Emoji keep their color in the menu-bar label (unlike a template-tinted
    /// `Image`), so the green/yellow/red severity stays visible.
    private static func statusIcon(for status: GitMonitor.Status) -> String {
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
