import SwiftUI

/// The menu-bar dropdown content. Because the style is `.menu`, `Text` and
/// `Button` render as native menu items.
///
/// One submenu per configured repo, each with its own severity icon, an
/// "Uncommitted" row, its recent commits listed below a divider, and — below
/// a further divider, each independently toggleable from Settings → General
/// (`showOpenInFinder`/`showOpenInTerminal`, both on by default) —
/// "Open in Finder"/"Open in Terminal" for that repo's folder. The menu-bar
/// label itself only shows the aggregate across all of them.
struct MenuContent: View {
    @ObservedObject var monitor: AppMonitor
    /// Read for `showOpenInFinder`/`showOpenInTerminal` (Settings → General).
    @ObservedObject var settings: Settings

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

    /// The content of one repo's submenu: error/empty state or a single
    /// "Uncommitted" row (opening the split-view window with every changed
    /// file), then — separated by a divider — the recent commits, each its
    /// own row.
    @ViewBuilder
    private func repoMenu(_ repo: RepoConfig, _ repoMonitor: RepoMonitor) -> some View {
        if let errorMessage = repoMonitor.errorMessage {
            Text("⚠️ \(errorMessage)")
        } else if repoMonitor.changes.isEmpty {
            Text(L10n.noChanges)
        } else {
            Button(uncommittedLabel(repoMonitor)) {
                openWindow(id: "uncommitted", value: repo.id)
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        if !repoMonitor.commits.isEmpty {
            Divider()
            ForEach(repoMonitor.commits) { commit in
                Button(commitLabel(commit)) {
                    openWindow(id: "commit", value: RepoCommit(repoID: repo.id, repoPath: repo.path, commit: commit))
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }

        if settings.showOpenInFinder || settings.showOpenInTerminal {
            Divider()
            if settings.showOpenInFinder {
                Button(L10n.openInFinder) { openInFinder(repo) }
            }
            if settings.showOpenInTerminal {
                Button(L10n.openInTerminal) { openInTerminal(repo) }
            }
        }
    }

    /// Opens the repo's folder in Finder, like double-clicking it there.
    private func openInFinder(_ repo: RepoConfig) {
        NSWorkspace.shared.open(URL(fileURLWithPath: repo.path))
    }

    /// Opens a new Terminal window at the repo's folder.
    ///
    /// Shells out to `/usr/bin/open` (a system binary, always at this fixed
    /// path — unlike `git`, no `-C`-style "run in this directory" flag exists
    /// for launching another app) rather than using `NSWorkspace`, which has
    /// no equivalent of `open -a <app> <path>` for opening a *folder* in an
    /// app that isn't already running on it.
    private func openInTerminal(_ repo: RepoConfig) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", repo.path]
        try? process.run()
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

    /// The "Uncommitted" row's label: category counts, e.g. "Uncommitted (1
    /// changed, 1 new)". Only non-zero categories are listed.
    private func uncommittedLabel(_ repoMonitor: RepoMonitor) -> String {
        var parts: [String] = []
        let changed = repoMonitor.changedFiles.count
        let new = repoMonitor.newFiles.count
        let deleted = repoMonitor.deletedFiles.count
        if changed > 0 { parts.append(L10n.changedCount(changed)) }
        if new > 0 { parts.append(L10n.newCount(new)) }
        if deleted > 0 { parts.append(L10n.deletedCount(deleted)) }
        return "\(L10n.uncommitted) (\(parts.joined(separator: ", ")))"
    }
}
