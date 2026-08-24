import Foundation

/// File-type detection used to decide which renderings a file supports.
///
/// Stage 1 only distinguishes Markdown (which can be previewed via the
/// built-in Web view and, optionally, `viewmd`) from everything else (diff
/// only). Extend `markdownExtensions` — or add new kinds here — as more
/// file-type-dependent rendering is added.
enum FileKind {
    /// Extensions treated as Markdown (lowercased, without the dot).
    static let markdownExtensions: Set<String> = [
        "md", "markdown", "mdown", "mkd", "mkdn", "mdwn",
    ]

    /// Whether the file at `path` is Markdown (by extension).
    static func isMarkdown(_ path: String) -> Bool {
        markdownExtensions.contains((path as NSString).pathExtension.lowercased())
    }
}
