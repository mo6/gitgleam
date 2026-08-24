import SwiftUI

/// Window showing the changes introduced by one commit as a split view: a
/// sidebar listing the changed files and a detail pane showing the selected
/// file's colored diff. The first file is selected automatically; changing the
/// selection updates the pane.
struct CommitDetailView: View {
    let commit: Commit
    /// Repository the commit belongs to (used to run `git show`).
    let repoPath: String
    /// viewmd settings, forwarded to each file pane (nil = no viewmd Preview).
    let preview: AppConfig.PreviewSettings?
    /// Which view a Markdown file should open in.
    let defaultView: ViewMode

    @State private var files: [CommitFile] = []
    @State private var selection: CommitFile.ID?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            splitView
        }
        .frame(minWidth: 860, minHeight: 480)
        .task(id: commit.id) { await load() }
    }

    // MARK: - Parts

    /// Commit metadata: subject, short SHA, author, date and file count.
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(commit.subject)
                .font(.headline)
                .lineLimit(2)
                .textSelection(.enabled)

            HStack(spacing: 16) {
                Text(commit.shortSHA)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text(commit.author)
                    .foregroundStyle(.secondary)
                Text(commit.date)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Sidebar file list plus the selected file's diff.
    @ViewBuilder
    private var splitView: some View {
        NavigationSplitView {
            List(files, selection: $selection) { file in
                fileRow(file)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 300, max: 460)
        } detail: {
            if let file = selectedFile {
                CommitFilePane(
                    sha: commit.sha, file: file, repoPath: repoPath,
                    preview: preview, defaultView: defaultView
                )
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text(L10n.noChanges)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// One sidebar row: a colored status letter and the file name, with the
    /// full path as a tooltip and secondary line.
    private func fileRow(_ file: CommitFile) -> some View {
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
        .tag(file.id)
    }

    // MARK: - Helpers

    /// The `CommitFile` matching the current selection, if any.
    private var selectedFile: CommitFile? {
        files.first { $0.id == selection }
    }

    /// A color for a name-status letter, matching the diff/menu severity feel.
    private func statusColor(_ letter: String) -> Color {
        switch letter {
        case "A": return .green
        case "D": return .red
        case "R", "C": return .blue
        default: return .yellow // M, T, …
        }
    }

    private func load() async {
        isLoading = true
        files = await Git.commitFiles(sha: commit.sha, at: repoPath)
        // Select the first file by default so the pane isn't empty.
        selection = files.first?.id
        isLoading = false
    }
}
