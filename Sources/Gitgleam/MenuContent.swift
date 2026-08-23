import SwiftUI

/// The menu-bar dropdown content. Because the style is `.menu`, `Text` and
/// `Button` render as native menu items.
///
/// One submenu per configured repo, each with its own severity icon and its
/// own Changed/New/Deleted sections + Recent commits — the menu-bar label
/// itself only shows the aggregate across all of them.
struct MenuContent: View {
    @ObservedObject var monitor: AppMonitor

    // Opens separate windows; one diff/commit/all-changes window per repo.
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let repos = monitor.orderedMonitors
        if monitor.orderedEntries.isEmpty {
            Text(L10n.noRepositoriesConfigured)
        } else {
            ForEach(repos, id: \.repo.id) { entry in
                Menu(repoLabel(entry.repo, entry.monitor)) {
                    repoMenu(entry.repo, entry.monitor)
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
            monitor.refreshAll()
        }
        Button(L10n.quit) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    /// One repo's submenu title: its own severity icon, label, and count.
    private func repoLabel(_ repo: RepoConfig, _ repoMonitor: RepoMonitor) -> String {
        let icon = statusIcon(for: repoMonitor.status)
        return repoMonitor.status == .error
            ? "\(icon) \(repo.label)"
            : "\(icon) \(repo.label) (\(repoMonitor.changes.count))"
    }

    private func statusIcon(for status: RepoMonitor.Status) -> String {
        switch status {
        case .error: return "⚠️"
        case .clean: return "🟢"
        case .few:   return "🟡"
        case .many:  return "🔴"
        }
    }

    /// The content of one repo's submenu: error/empty state or the three file
    /// sections, the overflow row, and a nested Recent commits submenu.
    @ViewBuilder
    private func repoMenu(_ repo: RepoConfig, _ repoMonitor: RepoMonitor) -> some View {
        if let errorMessage = repoMonitor.errorMessage {
            Text("⚠️ \(errorMessage)")
        } else if repoMonitor.changes.isEmpty {
            Text(L10n.noChanges)
        } else {
            let display = displayedSections(repoMonitor, max: repoMonitor.maxMenuEntries)
            ForEach(display.sections) { section in
                fileSection(repo, section.title, section.files, selectable: section.selectable)
            }

            if display.hidden > 0 {
                Divider()
                Text(L10n.moreNotShown(display.hidden))
                Button(L10n.showAll(display.total)) {
                    openWindow(id: "all", value: repo.id)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }

        if !repoMonitor.commits.isEmpty {
            Divider()
            Menu(L10n.recentCommits) {
                ForEach(repoMonitor.commits) { commit in
                    Button(commitLabel(commit)) {
                        openWindow(id: "commit", value: RepoCommit(repoID: repo.id, repoPath: repo.path, commit: commit))
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
            }
        }
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
    private func displayedSections(_ repoMonitor: RepoMonitor, max: Int) -> (sections: [DisplaySection], hidden: Int, total: Int) {
        let ordered: [(title: String, files: [FileChange], selectable: Bool)] = [
            (L10n.changed, repoMonitor.changedFiles, true),
            (L10n.new, repoMonitor.newFiles, true),
            (L10n.deleted, repoMonitor.deletedFiles, false),
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
    private func fileSection(_ repo: RepoConfig, _ title: String, _ files: [FileChange], selectable: Bool) -> some View {
        if !files.isEmpty {
            Section(title) {
                ForEach(files) { change in
                    if selectable {
                        Button(change.path) {
                            openWindow(id: "diff", value: RepoFileChange(repoID: repo.id, repoPath: repo.path, change: change))
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
