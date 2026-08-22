import SwiftUI

/// A colored, scrollable rendering of a unified diff.
///
/// Shared by the per-file diff window (`DiffView`) and the commit file pane
/// (`CommitFilePane`) so the +/- coloring can't drift between them. The
/// coloring/counting helpers are `static` so a header can report the
/// added/removed line counts without instantiating the view.
///
/// The diff is rendered (via `MonospacedTextScroll`) as a single monospaced
/// `Text` built from an `AttributedString`, one colored run per line — see that
/// view for why a single fixed-size `Text` is required for horizontal scrolling.
struct ColoredDiffView: View {
    /// The raw unified-diff text.
    let diff: String

    var body: some View {
        MonospacedTextScroll(attributed: Self.attributed(from: diff))
    }

    // MARK: - Diff processing

    /// One diff line with the color that goes with it.
    struct DiffLine {
        let text: String
        let color: Color
    }

    /// Builds a single colored `AttributedString` from the diff, one colored
    /// run per line. Empty lines are rendered as a single space so they keep
    /// their height.
    static func attributed(from diff: String) -> AttributedString {
        var result = AttributedString()
        let all = lines(from: diff)
        for (index, line) in all.enumerated() {
            if index > 0 { result.append(AttributedString("\n")) }
            var run = AttributedString(line.text.isEmpty ? " " : line.text)
            run.foregroundColor = line.color
            result.append(run)
        }
        return result
    }

    /// Splits a diff into colored lines (empty subsequences preserved so blank
    /// context lines are not collapsed).
    static func lines(from diff: String) -> [DiffLine] {
        diff.split(separator: "\n", omittingEmptySubsequences: false).map { sub in
            let text = String(sub)
            return DiffLine(text: text, color: color(for: text))
        }
    }

    /// Number of added lines (`+`, excluding the `+++` file header).
    static func addedCount(in lines: [DiffLine]) -> Int {
        lines.filter { $0.text.hasPrefix("+") && !$0.text.hasPrefix("+++") }.count
    }

    /// Number of removed lines (`-`, excluding the `---` file header).
    static func removedCount(in lines: [DiffLine]) -> Int {
        lines.filter { $0.text.hasPrefix("-") && !$0.text.hasPrefix("---") }.count
    }

    /// Colors a diff line: green for additions, red for deletions, cyan for
    /// hunk headers and gray for the file header.
    static func color(for line: String) -> Color {
        if line.hasPrefix("+++") || line.hasPrefix("---") {
            return .secondary
        } else if line.hasPrefix("+") {
            return .green
        } else if line.hasPrefix("-") {
            return .red
        } else if line.hasPrefix("@@") {
            return .cyan
        } else if line.hasPrefix("diff ") || line.hasPrefix("index ")
            || line.hasPrefix("new file") || line.hasPrefix("deleted file")
            || line.hasPrefix("rename ") || line.hasPrefix("similarity ") {
            return .secondary
        } else {
            return .primary
        }
    }
}
