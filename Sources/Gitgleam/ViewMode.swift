import Foundation

/// Which rendering a file pane is showing.
///
/// `diff` is the colored unified diff at git's default context (a few lines
/// around each change); `diffFull` is the same colored diff at unlimited
/// context, so the whole file is shown with the +/- lines colored in place.
/// Both are always available, for every file. `preview` is the file rendered
/// as formatted Markdown via `viewmd` (only when a viewmd path is configured
/// and the file is Markdown). `web` is the same file rendered as HTML in a
/// `WKWebView` with bundled marked + mermaid.js (Markdown only; available
/// even without viewmd). The raw values match the `--default-view` flag.
enum ViewMode: String, Hashable, Codable {
    case diff
    case diffFull = "diff-full"
    case preview
    case web

    /// Initial mode for a file given the user's default and what's available.
    ///
    /// Non-Markdown files can only be `diff`/`diffFull` (`preview`/`web` need
    /// Markdown, so they fall back to `diff`). `preview` without viewmd falls
    /// back to `web`, so "render the Markdown" still has a renderer when
    /// viewmd isn't configured.
    static func initial(preferred: ViewMode, isMarkdown: Bool, hasViewmd: Bool) -> ViewMode {
        guard isMarkdown else { return preferred == .diffFull ? .diffFull : .diff }
        switch preferred {
        case .diff: return .diff
        case .diffFull: return .diffFull
        case .web: return .web
        case .preview: return hasViewmd ? .preview : .web
        }
    }
}
