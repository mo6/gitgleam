import SwiftUI

/// Window showing the colored diff of one file, with a short summary
/// (status and the number of added/removed lines) at the top.
///
/// For a Markdown file, when a viewmd path is configured (`preview != nil`), a
/// Diff/Preview toggle appears: Preview renders the working-tree file as
/// formatted Markdown (Mermaid included) via `viewmd`.
struct DiffView: View {
    let change: FileChange
    /// Repository the file belongs to (used to run `git diff` / read the file).
    let repoPath: String
    /// Preview settings, or nil when preview is unavailable (diff only).
    let preview: AppConfig.PreviewSettings?

    @State private var mode: ViewMode
    @State private var diff: String = ""
    @State private var previewText: AttributedString?
    @State private var isLoading = true

    // Matches viewmd's rendered palette (including the `viewmd:mark` highlight
    // background) to the window's actual appearance — see `Viewmd.render`.
    @Environment(\.colorScheme) private var colorScheme

    init(change: FileChange, repoPath: String, preview: AppConfig.PreviewSettings?) {
        self.change = change
        self.repoPath = repoPath
        self.preview = preview
        // Open in preview when the file supports it; otherwise the diff.
        let canPreview = preview != nil && FileKind.isMarkdown(change.path)
        _mode = State(initialValue: canPreview ? preview!.defaultView : .diff)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 640, minHeight: 420)
        // Reload on file change or when toggling to a not-yet-loaded preview.
        .task(id: taskKey) { await load() }
    }

    // MARK: - Parts

    /// Header with the file name, status, +/- counts, and the view toggle.
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

    // MARK: - Diff processing

    /// The diff split into colored lines, for the header's +/- counts.
    private var lines: [ColoredDiffView.DiffLine] { ColoredDiffView.lines(from: diff) }
    private var addedCount: Int { ColoredDiffView.addedCount(in: lines) }
    private var removedCount: Int { ColoredDiffView.removedCount(in: lines) }

    private func load() async {
        isLoading = true
        // Always load the diff: it drives the +/- counts and is the preview's
        // fallback. Loaded once; toggling modes reuses it.
        if diff.isEmpty {
            diff = await Git.diff(for: change, at: repoPath)
        }
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
