import SwiftUI

/// Window listing *all* changed files, grouped into Changed / New / Deleted.
///
/// Opened from the menu's "Show all changes…" overflow action when the entry
/// cap hides files. Unlike the menu it has no row limit, and it observes the
/// shared `GitMonitor`, so it updates live as the repository changes. Clicking
/// a changed/new file opens its diff window (the same `WindowGroup` the menu
/// uses); deleted files are shown as plain text.
struct AllChangesView: View {
    @ObservedObject var monitor: GitMonitor
    /// Repository the files belong to (forwarded to the diff window).
    let repoPath: String

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            if let errorMessage = monitor.errorMessage {
                message("⚠️ \(errorMessage)")
            } else if monitor.changes.isEmpty {
                message(L10n.noChanges)
            } else {
                List {
                    fileSection(L10n.changed, monitor.changedFiles, selectable: true)
                    fileSection(L10n.new, monitor.newFiles, selectable: true)
                    fileSection(L10n.deleted, monitor.deletedFiles, selectable: false)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 480)
    }

    /// Centered single-line state (empty or error).
    private func message(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// One list section. Empty sections are omitted. Clickable files open their
    /// diff window; non-clickable ones show text only.
    @ViewBuilder
    private func fileSection(_ title: String, _ files: [FileChange], selectable: Bool) -> some View {
        if !files.isEmpty {
            Section(title) {
                ForEach(files) { change in
                    if selectable {
                        Button {
                            openWindow(id: "diff", value: change)
                            // The app is an accessory (no Dock icon); bring the
                            // window to the front so it gets focus.
                            NSApp.activate(ignoringOtherApps: true)
                        } label: {
                            Text(change.path)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(change.path)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
