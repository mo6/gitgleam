import SwiftUI

/// A colored, line-numbered, word-wrapping rendering of a unified diff.
///
/// Shared by the per-file diff window (`DiffView`) and the commit file pane
/// (`CommitFilePane`) so the +/- coloring can't drift between them. The
/// coloring/counting helpers are `static` so a header can report the
/// added/removed line counts without instantiating the view.
///
/// Unlike `MonospacedTextScroll` (used for the viewmd ANSI preview, which
/// always needs a fixed-size single `Text` to preserve box-drawing
/// alignment and scrolls horizontally), a diff line's own wrapping is a
/// Settings choice (`Settings.wrapDiffLines`, the Diff section's "Wrap
/// lines" toggle): wrapped, each gets its own row so a two-column old/new
/// line-number gutter can stay aligned with it; unwrapped, each row keeps
/// its natural single-line width and the whole view scrolls horizontally to
/// reach it — matching what `MonospacedTextScroll` did before per-line
/// gutters made a single merged `Text` impossible.
struct ColoredDiffView: View {
    /// The raw unified-diff text.
    let diff: String
    /// Wrap long lines to the pane width, vs. keep them on one line and
    /// scroll horizontally to read them.
    let wrapLines: Bool

    // Added/removed row tints are theme-aware (see `DiffLine.Kind.background`).
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let all = Self.lines(from: diff)
        let columnWidth = Self.numberColumnWidth(for: all)
        GeometryReader { geo in
            ScrollView(wrapLines ? .vertical : [.horizontal, .vertical]) {
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
                            if wrapLines {
                                Text(Self.attributedText(for: line, colorScheme: colorScheme))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(Self.attributedText(for: line, colorScheme: colorScheme))
                                    .fixedSize()
                            }
                        }
                        .textSelection(.enabled)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 1)
                        .background(line.kind.background(for: colorScheme))
                        .frame(maxWidth: wrapLines ? .infinity : nil, alignment: .leading)
                    }
                }
                .padding(.vertical, 8)
                .frame(minWidth: wrapLines ? nil : geo.size.width, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Diff processing

    /// One diff line with the kind that determines its coloring, and its
    /// position in the old/new files (nil where a number doesn't apply, e.g.
    /// header lines, or on the side a line doesn't exist on).
    struct DiffLine {
        let text: String
        let kind: Kind
        var oldLine: Int?
        var newLine: Int?
        /// Word-level changed spans within `text` (a replaced line's inner
        /// edits — see `addInlineHighlights`), rendered with a stronger
        /// background than the rest of the line. Empty when a line has no
        /// paired opposite-side line to diff against, or when the two lines
        /// share no common tokens (nothing more specific than "the whole
        /// line changed" to highlight).
        var innerHighlights: [Range<String.Index>] = []
    }

    /// What a diff line is, driving both its text color and (for added/
    /// removed lines) its full-width background tint — mirrors the
    /// background-tinted diff style of editors like VS Code/Claude Code
    /// rather than colored +/- text on an unmarked background.
    enum Kind {
        case added, removed, hunkHeader, fileHeader, context

        var textColor: Color {
            switch self {
            case .added, .removed, .context: return .primary
            case .hunkHeader: return .cyan
            case .fileHeader: return .secondary
            }
        }

        /// A translucent, theme-aware row tint — nil (no background) for
        /// anything but added/removed lines.
        func background(for colorScheme: ColorScheme) -> Color? {
            switch self {
            case .added: return .green.opacity(colorScheme == .dark ? 0.18 : 0.15)
            case .removed: return .red.opacity(colorScheme == .dark ? 0.18 : 0.13)
            case .hunkHeader, .fileHeader, .context: return nil
            }
        }

        /// A stronger, theme-aware tint for a line's inner word-level edits —
        /// nil for anything but added/removed lines.
        func innerHighlight(for colorScheme: ColorScheme) -> Color? {
            switch self {
            case .added: return .green.opacity(colorScheme == .dark ? 0.5 : 0.4)
            case .removed: return .red.opacity(colorScheme == .dark ? 0.5 : 0.35)
            case .hunkHeader, .fileHeader, .context: return nil
            }
        }
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
                result.append(DiffLine(text: text, kind: kind(for: text), oldLine: nil, newLine: nil))
                continue
            }
            var line = DiffLine(text: text, kind: kind(for: text), oldLine: nil, newLine: nil)
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
        addInlineHighlights(to: &result)
        return result
    }

    /// Builds the line's displayed text as an `AttributedString`: the kind's
    /// base text color, plus (for a replaced line's changed words) a
    /// stronger background over just those spans.
    static func attributedText(for line: DiffLine, colorScheme: ColorScheme) -> AttributedString {
        let text = line.text.isEmpty ? " " : line.text
        var attr = AttributedString(text)
        attr.foregroundColor = line.kind.textColor
        guard let highlight = line.kind.innerHighlight(for: colorScheme) else { return attr }
        for range in line.innerHighlights {
            guard let attrRange = Range(range, in: attr) else { continue }
            attr[attrRange].backgroundColor = highlight
        }
        return attr
    }

    /// Finds each contiguous "removed lines, then added lines" replace group
    /// (git's usual layout for a changed region) and, for each removed/added
    /// line paired by position within the group, marks the words that
    /// differ — a lightweight stand-in for git's own `--word-diff`, scoped to
    /// same-position line pairs rather than a global word diff over the
    /// whole hunk.
    private static func addInlineHighlights(to lines: inout [DiffLine]) {
        var i = 0
        while i < lines.count {
            guard lines[i].kind == .removed else { i += 1; continue }
            var removedEnd = i
            while removedEnd < lines.count, lines[removedEnd].kind == .removed { removedEnd += 1 }
            var addedEnd = removedEnd
            while addedEnd < lines.count, lines[addedEnd].kind == .added { addedEnd += 1 }
            let pairCount = min(removedEnd - i, addedEnd - removedEnd)
            for k in 0..<pairCount {
                let (oldHighlights, newHighlights) = highlightsForPair(lines[i + k], lines[removedEnd + k])
                lines[i + k].innerHighlights = oldHighlights
                lines[removedEnd + k].innerHighlights = newHighlights
            }
            i = addedEnd
        }
    }

    /// Word-diffs one removed/added line pair and returns the changed spans
    /// on each side (empty on both when the two share no common tokens at
    /// all — then the whole line already reads as changed via the row
    /// background, and marking every word would add nothing).
    private static func highlightsForPair(
        _ oldLine: DiffLine, _ newLine: DiffLine
    ) -> (old: [Range<String.Index>], new: [Range<String.Index>]) {
        let oldTokens = tokenize(oldLine.text.dropFirst())
        let newTokens = tokenize(newLine.text.dropFirst())
        let (oldMarks, newMarks) = wordDiff(oldTokens.map(\.text), newTokens.map(\.text))
        guard oldMarks.contains(false) || newMarks.contains(false) else { return ([], []) }
        return (
            zip(oldTokens, oldMarks).filter(\.1).map(\.0.range),
            zip(newTokens, newMarks).filter(\.1).map(\.0.range)
        )
    }

    /// Splits a line's content into whitespace/non-whitespace runs, each
    /// paired with its range in the original string (so a changed token's
    /// span can be highlighted directly, without re-searching for it).
    private static func tokenize(_ s: Substring) -> [(text: String, range: Range<String.Index>)] {
        guard s.startIndex != s.endIndex else { return [] }
        var tokens: [(String, Range<String.Index>)] = []
        var start = s.startIndex
        var runIsSpace = s[start].isWhitespace
        var idx = s.index(after: start)
        while idx < s.endIndex {
            let isSpace = s[idx].isWhitespace
            if isSpace != runIsSpace {
                tokens.append((String(s[start..<idx]), start..<idx))
                start = idx
                runIsSpace = isSpace
            }
            idx = s.index(after: idx)
        }
        tokens.append((String(s[start..<s.endIndex]), start..<s.endIndex))
        return tokens
    }

    /// A classic LCS-based token diff: `true` at a position means that token
    /// is not part of the longest common subsequence, i.e. it changed.
    private static func wordDiff(_ old: [String], _ new: [String]) -> (old: [Bool], new: [Bool]) {
        let n = old.count, m = new.count
        guard n > 0, m > 0 else { return (Array(repeating: true, count: n), Array(repeating: true, count: m)) }
        var lcs = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                lcs[i][j] = old[i] == new[j] ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1])
            }
        }
        var oldMarks = Array(repeating: true, count: n)
        var newMarks = Array(repeating: true, count: m)
        var i = 0, j = 0
        while i < n, j < m {
            if old[i] == new[j] {
                oldMarks[i] = false
                newMarks[j] = false
                i += 1
                j += 1
            } else if lcs[i + 1][j] >= lcs[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }
        return (oldMarks, newMarks)
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
        lines.filter { $0.kind == .added }.count
    }

    /// Number of removed lines (`-`, excluding the `---` file header).
    static func removedCount(in lines: [DiffLine]) -> Int {
        lines.filter { $0.kind == .removed }.count
    }

    /// Classifies a diff line: added/removed for `+`/`-` content lines
    /// (excluding the `+++`/`---` file headers), hunk header for `@@` lines,
    /// file header for the `diff --git`/`index`/etc. preamble, context
    /// otherwise.
    static func kind(for line: String) -> Kind {
        if line.hasPrefix("+++") || line.hasPrefix("---") {
            return .fileHeader
        } else if line.hasPrefix("+") {
            return .added
        } else if line.hasPrefix("-") {
            return .removed
        } else if line.hasPrefix("@@") {
            return .hunkHeader
        } else if line.hasPrefix("diff ") || line.hasPrefix("index ")
            || line.hasPrefix("new file") || line.hasPrefix("deleted file")
            || line.hasPrefix("rename ") || line.hasPrefix("similarity ") {
            return .fileHeader
        } else {
            return .context
        }
    }
}
