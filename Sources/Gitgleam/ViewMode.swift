import Foundation

/// Which rendering a diff/commit window is showing for a file.
///
/// `diff` is the colored unified diff (always available). `preview` is the
/// file rendered as formatted Markdown via `viewmd` (only when a viewmd path is
/// configured and the file is Markdown). The raw values match the
/// `--default-view` flag.
enum ViewMode: String, Hashable, Codable {
    case diff
    case preview
}
