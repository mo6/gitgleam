import SwiftUI

/// Window showing every uncommitted change in one repo as a split view: a
/// sidebar listing the changed/new/deleted files and a detail pane showing
/// the selected file's colored diff. Mirrors `CommitDetailView`'s shape so
/// uncommitted changes and commits are presented the same way.
///
/// Opened from that repo's single "Uncommitted" menu item (replacing the old
/// per-category submenu + overflow "Show all changes" window). It observes
/// the repo's `RepoMonitor`, so it updates live as the repository changes —
/// including the selection, which re-anchors to the first file if the
/// selected one disappears (e.g. it gets committed elsewhere).
struct UncommittedView: View {
    @ObservedObject var monitor: RepoMonitor
    /// The repo these files belong to (used to run `git diff` / read files).
    let repo: RepoConfig
    /// viewmd settings, forwarded to the file pane (nil = no viewmd Preview).
    let preview: AppConfig.PreviewSettings?
    /// Which view a file should open in.
    let defaultView: ViewMode

    @State private var selection: FileChange.ID?

    var body: some View {
        Group {
            if let errorMessage = monitor.errorMessage {
                message("⚠️ \(errorMessage)")
            } else if monitor.changes.isEmpty {
                message(L10n.noChanges)
            } else {
                splitView
            }
        }
        .frame(minWidth: 860, minHeight: 480)
        .onAppear(perform: syncSelection)
        .onChange(of: monitor.changes) { syncSelection() }
    }

    // MARK: - Parts

    /// Sidebar file list, grouped into Changed/New/Deleted, plus the selected
    /// file's diff.
    @ViewBuilder
    private var splitView: some View {
        NavigationSplitView {
            List(selection: $selection) {
                fileSection(L10n.changed, monitor.changedFiles)
                fileSection(L10n.new, monitor.newFiles)
                fileSection(L10n.deleted, monitor.deletedFiles)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 300, max: 460)
        } detail: {
            if let file = selectedFile {
                FileDiffPane(change: file, repoPath: repo.path, preview: preview, defaultView: defaultView)
            } else {
                Text(L10n.noChanges)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// One sidebar section. Empty sections are omitted.
    @ViewBuilder
    private func fileSection(_ title: String, _ files: [FileChange]) -> some View {
        if !files.isEmpty {
            Section(title) {
                ForEach(files) { file in
                    fileRow(file).tag(file.id)
                }
            }
        }
    }

    /// One sidebar row: a colored status letter and the file name, with the
    /// full path as a tooltip and secondary line.
    private func fileRow(_ file: FileChange) -> some View {
        HStack(spacing: 8) {
            Text(file.statusLetter)
                .font(.system(.body, design: .monospaced).bold())
                .foregroundStyle(statusColor(file.statusLetter))
                .frame(width: 14, alignment: .center)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.fileName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(file.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .help(file.path)
    }

    /// Centered single-line state (empty or error).
    private func message(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    /// The `FileChange` matching the current selection, if any.
    private var selectedFile: FileChange? {
        monitor.changes.first { $0.id == selection }
    }

    /// Re-anchors the selection to the first file when there is none yet, or
    /// the previously selected one is no longer in `monitor.changes`.
    private func syncSelection() {
        if selection == nil || !monitor.changes.contains(where: { $0.id == selection }) {
            selection = monitor.changes.first?.id
        }
    }

    /// A color for a status letter, matching the diff/menu severity feel.
    /// Mirrors `CommitDetailView.statusColor`, plus `?` for untracked files.
    private func statusColor(_ letter: String) -> Color {
        switch letter {
        case "A", "?": return .green
        case "D": return .red
        case "R", "C": return .blue
        default: return .yellow // M, U, …
        }
    }
}
