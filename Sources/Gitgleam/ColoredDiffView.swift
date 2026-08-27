import SwiftUI

/// A colored, line-numbered, word-wrapping rendering of a unified diff.
///
/// Shared by the per-file diff window (`DiffView`) and the commit file pane
/// (`CommitFilePane`) so the +/- coloring can't drift between them. The
/// coloring/counting helpers are `static` so a header can report the
/// added/removed line counts without instantiating the view.
///
/// Unlike `MonospacedTextScroll` (used for the viewmd ANSI preview, which
/// needs a fixed-size single `Text` to preserve box-drawing alignment and
/// scrolls horizontally), diff lines wrap to the available width and each
/// gets its own row so a two-column old/new line-number gutter can stay
/// aligned with it.
struct ColoredDiffView: View {
    /// The raw unified-diff text.
    let diff: String

    var body: some View {
        let all = Self.lines(from: diff)
        let columnWidth = Self.numberColumnWidth(for: all)
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(all.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 0) {
                        Text(line.oldLine.map(String.init) ?? "")
                            .foregroundStyle(.secondary)
                            .frame(width: columnWidth, alignment: .trailing)
                        Text(line.newLine.map(String.init) ?? "")
                            .foregroundStyle(.secondary)
                            .frame(width: columnWidth, alignment: .trailing)
                            .padding(.trailing, 8)
                        Text(line.text.isEmpty ? " " : line.text)
                            .foregroundColor(line.color)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .textSelection(.enabled)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 1)
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Diff processing

    /// One diff line with the color that goes with it and its position in the
    /// old/new files (nil where a number doesn't apply, e.g. header lines, or
    /// on the side a line doesn't exist on).
    struct DiffLine {
        let text: String
        let color: Color
        var oldLine: Int?
        var newLine: Int?
    }

    /// Splits a diff into colored lines (empty subsequences preserved so blank
    /// context lines are not collapsed), tracking old/new line numbers by
    /// parsing each hunk's `@@ -l,s +l,s @@` header.
    static func lines(from diff: String) -> [DiffLine] {
        var result: [DiffLine] = []
        var oldLine: Int?
        var newLine: Int?
        for sub in diff.split(separator: "\n", omittingEmptySubsequences: false) {
            let text = String(sub)
            if let (start1, start2) = hunkStarts(text) {
                oldLine = start1
                newLine = start2
                result.append(DiffLine(text: text, color: color(for: text), oldLine: nil, newLine: nil))
                continue
            }
            var line = DiffLine(text: text, color: color(for: text), oldLine: nil, newLine: nil)
            if text.hasPrefix("+") && !text.hasPrefix("+++"), let n = newLine {
                line.newLine = n
                newLine = n + 1
            } else if text.hasPrefix("-") && !text.hasPrefix("---"), let o = oldLine {
                line.oldLine = o
                oldLine = o + 1
            } else if oldLine != nil, newLine != nil,
                      !text.hasPrefix("diff "), !text.hasPrefix("index "),
                      !text.hasPrefix("new file"), !text.hasPrefix("deleted file"),
                      !text.hasPrefix("rename "), !text.hasPrefix("similarity "),
                      !text.hasPrefix("+++"), !text.hasPrefix("---") {
                line.oldLine = oldLine
                line.newLine = newLine
                oldLine! += 1
                newLine! += 1
            }
            result.append(line)
        }
        return result
    }

    /// Parses a hunk header (`@@ -l[,s] +l[,s] @@ ...`) into its old/new
    /// starting line numbers, or nil if `text` isn't one.
    private static func hunkStarts(_ text: String) -> (Int, Int)? {
        guard text.hasPrefix("@@ -") else { return nil }
        let parts = text.split(separator: " ")
        guard parts.count >= 3 else { return nil }
        let old = parts[1].dropFirst() // drop leading "-"
        let new = parts[2].dropFirst() // drop leading "+"
        guard let oldStart = Int(old.split(separator: ",").first ?? ""),
              let newStart = Int(new.split(separator: ",").first ?? "") else { return nil }
        return (oldStart, newStart)
    }

    /// A fixed width, in points, for the old/new line-number columns — wide
    /// enough for the largest line number in this diff.
    static func numberColumnWidth(for lines: [DiffLine]) -> CGFloat {
        let maxNumber = lines.reduce(0) { acc, line in
            max(acc, line.oldLine ?? 0, line.newLine ?? 0)
        }
        let digits = max(2, String(maxNumber).count)
        return CGFloat(digits) * 8 + 4
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
