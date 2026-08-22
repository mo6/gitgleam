import SwiftUI

/// App entry point. The UI lives entirely in the menu bar via `MenuBarExtra`;
/// the diff `WindowGroup` opens on demand when a file is clicked.
@main
struct GitgleamApp: App {
    // Attaches an AppDelegate so we can hide the Dock icon.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Parsed once at launch from the command-line flags.
    static let config = AppConfig.parse(CommandLine.arguments)

    // The observable that tracks git status, configured from the flags.
    @StateObject private var monitor = GitMonitor(config: GitgleamApp.config)

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
                DiffView(change: change, repoPath: Self.config.path, preview: Self.config.previewSettings)
                    .navigationTitle(change.path)
            }
        }
        .windowResizability(.contentSize)

        // Commit-detail window: one per commit, opened from the "Recent commits"
        // submenu with the chosen `Commit` as its value.
        WindowGroup(id: "commit", for: Commit.self) { $commit in
            if let commit {
                CommitDetailView(commit: commit, repoPath: Self.config.path, preview: Self.config.previewSettings)
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
