import Foundation

/// Which rendering a file pane is showing.
///
/// `diff` is the colored unified diff (always available). `preview` is the
/// file rendered as formatted Markdown via `viewmd` (only when a viewmd path is
/// configured and the file is Markdown). `web` is the same file rendered as
/// HTML in a `WKWebView` with bundled marked + mermaid.js (Markdown only;
/// available even without viewmd). The raw values match the `--default-view`
/// flag.
enum ViewMode: String, Hashable, Codable {
    case diff
    case preview
    case web

    /// Initial mode for a file given the user's default and what's available.
    ///
    /// Non-Markdown files are always `diff`. `preview` without viewmd falls
    /// back to `web`, so "render the Markdown" still has a renderer when
    /// viewmd isn't configured.
    static func initial(preferred: ViewMode, isMarkdown: Bool, hasViewmd: Bool) -> ViewMode {
        guard isMarkdown else { return .diff }
        switch preferred {
        case .diff: return .diff
        case .web: return .web
        case .preview: return hasViewmd ? .preview : .web
        }
    }
}
