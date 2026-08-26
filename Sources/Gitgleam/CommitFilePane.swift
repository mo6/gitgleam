import SwiftUI

/// The detail pane of the commit split view: a header (path, status and +/-
/// counts) above the colored diff a commit made to one file.
///
/// Every file gets a view toggle: Diff (short context) and Diff (full,
/// unlimited context) always; Markdown files additionally gain Web
/// (built-in HTML/Mermaid preview) always, and Preview (viewmd) when
/// `preview != nil`.
struct CommitFilePane: View {
    /// The commit whose change to `file` is shown.
    let sha: String
    let file: CommitFile
    /// Repository the commit belongs to (used to run `git show`).
    let repoPath: String
    /// viewmd settings, or nil when the viewmd Preview toggle is unavailable.
    let preview: AppConfig.PreviewSettings?
    /// Which view a file should open in (from Settings).
    let defaultView: ViewMode

    @State private var mode: ViewMode = .diff
    /// Full-context diff — always loaded: it drives the +/- counts, feeds the
    /// Markdown preview's change highlighting, and backs `.diffFull`.
    @State private var diff: String = ""
    /// Short-context diff, loaded lazily only when `mode == .diff`.
    @State private var shortDiff: String = ""
    @State private var previewText: AttributedString?
    @State private var webMarkdown: String?
    @State private var isLoading = true

    // Matches viewmd's rendered palette (including the `viewmd:mark` highlight
    // background) to the window's actual appearance — see `Viewmd.render`.
    // Also drives the Web preview's mermaid/page theme.
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
                Spacer()
                ViewModePicker(mode: $mode, isMarkdown: isMarkdown, hasViewmd: canViewmd)
            }
            .font(.subheadline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The diff, viewmd preview, or Web preview — or a loading indicator.
    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isMarkdown, mode == .web, let webMarkdown {
            WebPreviewView(markdown: webMarkdown, colorScheme: colorScheme)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if canViewmd, mode == .preview, let previewText {
            MonospacedTextScroll(attributed: previewText)
        } else if mode == .diff {
            // Short-context diff, or a preview that failed to render while in
            // .diff mode → fall back to it (it's always loaded regardless).
            ColoredDiffView(diff: shortDiff)
        } else {
            // .diffFull, or a preview that failed to render in any other
            // mode → the full-context diff (always loaded).
            ColoredDiffView(diff: diff)
        }
    }

    // MARK: - Helpers

    private var isMarkdown: Bool { FileKind.isMarkdown(file.path) }
    /// Whether the viewmd Preview toggle applies to this file.
    private var canViewmd: Bool { preview != nil && isMarkdown }

    /// Re-runs the load task when the file changes or the mode flips.
    private var taskKey: String { "\(file.id)#\(mode.rawValue)" }

    /// Sets the mode to this file's default. Clears any stale preview from a
    /// prior file.
    private func resetModeForCurrentFile() {
        previewText = nil
        webMarkdown = nil
        mode = ViewMode.initial(preferred: defaultView, isMarkdown: isMarkdown, hasViewmd: canViewmd)
    }

    // MARK: - Diff processing

    private var lines: [ColoredDiffView.DiffLine] { ColoredDiffView.lines(from: diff) }
    private var addedCount: Int { ColoredDiffView.addedCount(in: lines) }
    private var removedCount: Int { ColoredDiffView.removedCount(in: lines) }

    private func load() async {
        isLoading = true
        // Always load the full-context diff: it drives the +/- counts, feeds
        // Markdown change highlighting, and is the preview's fallback.
        diff = await Git.commitFileDiff(sha: sha, file: file.path, at: repoPath)
        if mode == .diff {
            shortDiff = await Git.commitFileDiff(sha: sha, file: file.path, at: repoPath, context: Git.shortDiffContext)
        }
        if isMarkdown, mode == .web, webMarkdown == nil {
            await loadWeb()
        } else if canViewmd, mode == .preview, previewText == nil {
            await loadPreview()
        }
        isLoading = false
    }

    /// Reads the commit's version of the file and injects `viewmd:mark`
    /// sentinels for the Web preview. On any failure `webMarkdown` stays nil
    /// and `content` falls back to the diff.
    private func loadWeb() async {
        guard let content = await Git.fileContents(ref: sha, file: file.path, at: repoPath) else { return }
        webMarkdown = MarkdownHighlighter.mark(content, unifiedDiff: diff)
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
            markdown: marked, width: preview.width, viewmdPath: preview.viewmdPath,
            theme: colorScheme == .dark ? .dark : .light, keepDebugFile: preview.debugKeepFiles
        ) {
            previewText = ANSIText.attributed(from: ansi, colorScheme: colorScheme)
        }
    }
}
