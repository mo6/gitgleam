import SwiftUI

/// The detail pane of the Uncommitted split view: a header (path, status and
/// +/- counts) above the colored diff of one working-tree file's uncommitted
/// change. Mirrors `CommitFilePane`, but reads the working tree via
/// `Git.diff(for:)` instead of a commit's `git show`.
///
/// Every file gets a view toggle: Diff (short context) and Diff (full,
/// unlimited context) always; Markdown files additionally gain Web
/// (built-in HTML/Mermaid preview) always, and Preview (viewmd) when
/// `preview != nil`.
struct FileDiffPane: View {
    let change: FileChange
    /// Repository the file belongs to (used to run `git diff` / read the file).
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

    private var isMarkdown: Bool { FileKind.isMarkdown(change.path) }
    /// Whether the viewmd Preview toggle applies to this file.
    private var canViewmd: Bool { preview != nil && isMarkdown }

    /// Re-runs the load task when the file changes or the mode flips.
    private var taskKey: String { "\(change.id)#\(mode.rawValue)" }

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
        diff = await Git.diff(for: change, at: repoPath)
        if mode == .diff {
            shortDiff = await Git.diff(for: change, at: repoPath, context: Git.shortDiffContext)
        }
        if isMarkdown, mode == .web, webMarkdown == nil {
            await loadWeb()
        } else if canViewmd, mode == .preview, previewText == nil {
            await loadPreview()
        }
        isLoading = false
    }

    /// Reads the working-tree file and injects `viewmd:mark` sentinels for the
    /// Web preview. On any failure `webMarkdown` stays nil and `content`
    /// falls back to the diff.
    private func loadWeb() async {
        guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else { return }
        webMarkdown = MarkdownHighlighter.mark(content, unifiedDiff: diff)
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
