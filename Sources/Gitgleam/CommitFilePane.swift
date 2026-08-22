import SwiftUI

/// The detail pane of the commit split view: a header (path, status and +/-
/// counts) above the colored diff a commit made to one file.
///
/// For a Markdown file, when a viewmd path is configured (`preview != nil`), a
/// Diff/Preview toggle appears: Preview renders the commit's version of the
/// file as formatted Markdown (Mermaid included) via `viewmd`.
struct CommitFilePane: View {
    /// The commit whose change to `file` is shown.
    let sha: String
    let file: CommitFile
    /// Repository the commit belongs to (used to run `git show`).
    let repoPath: String
    /// Preview settings, or nil when preview is unavailable (diff only).
    let preview: AppConfig.PreviewSettings?

    @State private var mode: ViewMode = .diff
    @State private var diff: String = ""
    @State private var previewText: AttributedString?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        // Reload when the selected file changes or the mode flips.
        .task(id: taskKey) { await load() }
        // A new selection resets the toggle to this file's default view.
        .onChange(of: file.id) { resetModeForCurrentFile() }
        .onAppear(perform: resetModeForCurrentFile)
    }

    // MARK: - Parts

    /// Header with the file path, status, +/- counts, and the view toggle.
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(file.path)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            HStack(spacing: 16) {
                Text(file.statusDescription)
                    .foregroundStyle(.secondary)
                Label("\(addedCount)", systemImage: "plus")
                    .foregroundStyle(.green)
                Label("\(removedCount)", systemImage: "minus")
                    .foregroundStyle(.red)
                if canPreview {
                    Spacer()
                    viewPicker
                }
            }
            .font(.subheadline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Diff/Preview segmented toggle (only shown when preview is available).
    private var viewPicker: some View {
        Picker("", selection: $mode) {
            Text(L10n.diffView).tag(ViewMode.diff)
            Text(L10n.preview).tag(ViewMode.preview)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }

    /// The diff or preview, or a loading indicator.
    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if canPreview, mode == .preview, let previewText {
            MonospacedTextScroll(attributed: previewText)
        } else {
            // Diff mode, or a preview that failed to render → the colored diff.
            ColoredDiffView(diff: diff)
        }
    }

    // MARK: - Helpers

    /// Whether the Diff/Preview toggle applies to this file.
    private var canPreview: Bool { preview != nil && FileKind.isMarkdown(file.path) }

    /// Re-runs the load task when the file changes or the mode flips.
    private var taskKey: String { "\(file.id)#\(mode.rawValue)" }

    /// Sets the mode to this file's default (preview for Markdown when
    /// available, else diff). Clears any stale preview from a prior file.
    private func resetModeForCurrentFile() {
        previewText = nil
        mode = canPreview ? preview!.defaultView : .diff
    }

    // MARK: - Diff processing

    private var lines: [ColoredDiffView.DiffLine] { ColoredDiffView.lines(from: diff) }
    private var addedCount: Int { ColoredDiffView.addedCount(in: lines) }
    private var removedCount: Int { ColoredDiffView.removedCount(in: lines) }

    private func load() async {
        isLoading = true
        // Always load the diff: it drives the +/- counts and is the preview's
        // fallback.
        diff = await Git.commitFileDiff(sha: sha, file: file.path, at: repoPath)
        if canPreview, mode == .preview, previewText == nil {
            await loadPreview()
        }
        isLoading = false
    }

    /// Renders the commit's version of the file as Markdown via viewmd. On any
    /// failure `previewText` stays nil and `content` falls back to the diff.
    private func loadPreview() async {
        guard let preview,
              let content = await Git.fileContents(ref: sha, file: file.path, at: repoPath) else { return }
        // Mark the blocks this commit changed so viewmd can highlight them
        // (invisible until viewmd supports it). `diff` is already loaded here.
        let marked = MarkdownHighlighter.mark(content, unifiedDiff: diff)
        if case let .success(ansi) = await Viewmd.render(
            markdown: marked, width: preview.width, viewmdPath: preview.viewmdPath
        ) {
            previewText = ANSIText.attributed(from: ansi)
        }
    }
}
