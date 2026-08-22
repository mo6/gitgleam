import SwiftUI

/// The menu-bar dropdown content. Because the style is `.menu`, `Text` and
/// `Button` render as native menu items.
struct MenuContent: View {
    @ObservedObject var monitor: GitMonitor

    // Opens separate windows; one diff window per file.
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let errorMessage = monitor.errorMessage {
            Text("⚠️ \(errorMessage)")
        } else if monitor.changes.isEmpty {
            Text(L10n.noChanges)
        } else {
            // Three sections, capped at a total of `maxMenuEntries` rows so a
            // large update can't overrun the menu. Changed and new files are
            // clickable and open a diff window; deleted files are not.
            let display = displayedSections(max: monitor.maxMenuEntries)
            ForEach(display.sections) { section in
                fileSection(section.title, section.files, selectable: section.selectable)
            }

            // Overflow: when the cap hid some files, point at the full-list
            // window. The count in the menu bar still reflects the true total.
            if display.hidden > 0 {
                Divider()
                Text(L10n.moreNotShown(display.hidden))
                Button(L10n.showAll(display.total)) {
                    openWindow(id: "all")
                    // The app is an accessory (no Dock icon); bring the window
                    // to the front so it gets focus.
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }

        // Recent commits as a submenu; each opens a commit-detail window.
        // Hidden when there are none (e.g. a repository with no commits yet).
        if !monitor.commits.isEmpty {
            Divider()
            Menu(L10n.recentCommits) {
                ForEach(monitor.commits) { commit in
                    Button(commitLabel(commit)) {
                        openWindow(id: "commit", value: commit)
                        // The app is an accessory (no Dock icon); bring the
                        // window to the front so it gets focus.
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
            }
        }

        Button(L10n.settings) {
            openWindow(id: "settings")
            // The app is an accessory (no Dock icon); bring the window to
            // the front so it gets focus.
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        Button(L10n.refresh) {
            monitor.refresh()
        }
        Button(L10n.quit) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    /// A menu label for a commit: date/time, short SHA, then a trimmed subject
    /// (capped so a long commit message can't stretch the submenu too far).
    private func commitLabel(_ commit: Commit) -> String {
        let maxSubject = 100
        let subject = commit.subject.count > maxSubject
            ? commit.subject.prefix(maxSubject - 1).trimmingCharacters(in: .whitespaces) + "…"
            : commit.subject
        return "\(commit.date)  \(commit.shortSHA)  \(subject)"
    }

    /// One section's worth of rows to render in the menu, after truncation.
    private struct DisplaySection: Identifiable {
        let title: String
        let files: [FileChange]
        let selectable: Bool
        var id: String { title }
    }

    /// Truncates the ordered sections (Changed → New → Deleted) to a total of
    /// `max` file rows, filling in order, and reports how many were hidden.
    private func displayedSections(max: Int) -> (sections: [DisplaySection], hidden: Int, total: Int) {
        let ordered: [(title: String, files: [FileChange], selectable: Bool)] = [
            (L10n.changed, monitor.changedFiles, true),
            (L10n.new, monitor.newFiles, true),
            (L10n.deleted, monitor.deletedFiles, false),
        ]

        let total = ordered.reduce(0) { $0 + $1.files.count }
        var remaining = max
        var result: [DisplaySection] = []
        for section in ordered where !section.files.isEmpty {
            guard remaining > 0 else { break }
            let shown = Array(section.files.prefix(remaining))
            remaining -= shown.count
            result.append(DisplaySection(title: section.title, files: shown, selectable: section.selectable))
        }

        let shownCount = result.reduce(0) { $0 + $1.files.count }
        return (result, total - shownCount, total)
    }

    /// Renders one menu section. Empty sections are omitted. Clickable files
    /// open their diff window; non-clickable ones show text only.
    @ViewBuilder
    private func fileSection(_ title: String, _ files: [FileChange], selectable: Bool) -> some View {
        if !files.isEmpty {
            Section(title) {
                ForEach(files) { change in
                    if selectable {
                        Button(change.path) {
                            openWindow(id: "diff", value: change)
                            // The app is an accessory (no Dock icon); bring the
                            // window to the front so it gets focus.
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    } else {
                        Text(change.path)
                    }
                }
            }
        }
    }
}
