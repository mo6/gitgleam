import SwiftUI

/// The detail pane of the Uncommitted split view: a header (path, status and
/// +/- counts) above the colored diff of one working-tree file's uncommitted
/// change. Mirrors `CommitFilePane`, but reads the working tree via
/// `Git.diff(for:)` instead of a commit's `git show`.
///
/// For a Markdown file, when a viewmd path is configured (`preview != nil`), a
/// Diff/Preview toggle appears: Preview renders the working-tree version of
/// the file as formatted Markdown (Mermaid included) via `viewmd`.
struct FileDiffPane: View {
    let change: FileChange
    /// Repository the file belongs to (used to run `git diff` / read the file).
    let repoPath: String
    /// Preview settings, or nil when preview is unavailable (diff only).
    let preview: AppConfig.PreviewSettings?

    @State private var mode: ViewMode = .diff
    @State private var diff: String = ""
    @State private var previewText: AttributedString?
    @State private var isLoading = true

    // Matches viewmd's rendered palette (including the `viewmd:mark` highlight
    // background) to the window's actual appearance — see `Viewmd.render`.
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        // Reload when the selected file changes or the mode flips.
        .task(id: taskKey) { await load() }
        // A new selection resets the toggle to this file's default view.
        .onChange(of: change.id) { resetModeForCurrentFile() }
        .onAppear(perform: resetModeForCurrentFile)
    }

    // MARK: - Parts

    /// Header with the file path, status, +/- counts, and the view toggle.
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(change.path)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            HStack(spacing: 16) {
                Text(change.statusDescription)
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
    private var canPreview: Bool { preview != nil && FileKind.isMarkdown(change.path) }

    /// Re-runs the load task when the file changes or the mode flips.
    private var taskKey: String { "\(change.id)#\(mode.rawValue)" }

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
        diff = await Git.diff(for: change, at: repoPath)
        if canPreview, mode == .preview, previewText == nil {
            await loadPreview()
        }
        isLoading = false
    }

    /// Renders the working-tree file as Markdown via viewmd. On any failure
    /// `previewText` stays nil and `content` falls back to the diff.
    private func loadPreview() async {
        guard let preview,
              let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else { return }
        // Mark the changed blocks so viewmd can highlight them (invisible until
        // viewmd supports it). `diff` is already loaded by the time we get here.
        let marked = MarkdownHighlighter.mark(content, unifiedDiff: diff)
        if case let .success(ansi) = await Viewmd.render(
            markdown: marked, width: preview.width, viewmdPath: preview.viewmdPath,
            theme: colorScheme == .dark ? .dark : .light, keepDebugFile: preview.debugKeepFiles
        ) {
            previewText = ANSIText.attributed(from: ansi, colorScheme: colorScheme)
        }
    }

    /// Absolute path of the working-tree file.
    private var fullPath: String { (repoPath as NSString).appendingPathComponent(change.path) }
}
