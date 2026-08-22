import Foundation

/// Wraps the changed regions of a Markdown file in `viewmd:mark` sentinel
/// comments so viewmd can render them highlighted (see viewmd issue
/// VIEWMD-0104). Gitgleam owns the diff → marker mapping; viewmd stays
/// git-agnostic and only has to render what is marked.
///
/// The sentinels are ordinary HTML comments, invisible to a viewmd that does
/// not yet understand them (and to every other Markdown renderer), so injecting
/// them is safe *ahead* of viewmd support — they simply don't highlight yet
/// (and add a little blank-line spacing around changed blocks in the meantime).
///
/// Granularity is block-level: a "block" is a maximal run of non-blank lines
/// (a fenced code / Mermaid block is kept whole — blank lines inside a fence do
/// not split it), which approximates Markdown blocks without a full parser. A
/// block is marked when any of its lines is an added/changed line in the diff;
/// a block whose every line is new is `added`, otherwise `changed`. Pure
/// deletions have no line in the after-file and are not marked (a known
/// first-cut limitation, matching VIEWMD-0104's non-goals).
enum MarkdownHighlighter {
    static let startPrefix = "<!-- viewmd:mark start kind="
    static let endMarker = "<!-- viewmd:mark end -->"

    /// Returns `content` with `viewmd:mark` sentinels around each changed block,
    /// derived from `diff` (a unified diff of the same file version). If the
    /// diff carries no additions (or isn't a diff), `content` is returned as-is.
    static func mark(_ content: String, unifiedDiff diff: String) -> String {
        let changed = changedNewFileLines(in: diff)
        guard !changed.isEmpty else { return content }

        let lines = content.components(separatedBy: "\n")
        var startKind: [Int: String] = [:]  // 1-based start line → kind
        var endLines: Set<Int> = []
        for block in blockRanges(in: lines) {
            let changedCount = (block.start...block.end).reduce(0) {
                $0 + (changed.contains($1) ? 1 : 0)
            }
            guard changedCount > 0 else { continue }
            let allNew = changedCount == (block.end - block.start + 1)
            startKind[block.start] = allNew ? "added" : "changed"
            endLines.insert(block.end)
        }
        guard !startKind.isEmpty else { return content }

        var out: [String] = []
        out.reserveCapacity(lines.count + startKind.count * 2)
        for (idx, line) in lines.enumerated() {
            let n = idx + 1
            if let kind = startKind[n] { out.append("\(startPrefix)\(kind) -->") }
            out.append(line)
            if endLines.contains(n) { out.append(endMarker) }
        }
        return out.joined(separator: "\n")
    }

    // MARK: - Diff parsing

    /// The set of 1-based new-file line numbers that are additions in `diff`
    /// (the lines that exist, changed, in the file we are about to render).
    private static func changedNewFileLines(in diff: String) -> Set<Int> {
        var result: Set<Int> = []
        var newLine = 0
        var inHunk = false
        for raw in diff.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            if line.isEmpty { continue } // only a trailing split artifact; real diff lines have a prefix
            if line.hasPrefix("@@") {
                if let start = hunkNewStart(line) { newLine = start; inHunk = true }
                continue
            }
            guard inHunk else { continue }
            if line.hasPrefix("+++") || line.hasPrefix("---") { continue } // file headers
            switch line.first {
            case "+": result.insert(newLine); newLine += 1
            case "-": break                                     // deletion: no new-file line
            case "\\": break                                    // "\ No newline at end of file"
            default: newLine += 1                               // context (leading space)
            }
        }
        return result
    }

    /// Parses the new-file start line from a hunk header `@@ -a,b +c,d @@`.
    private static func hunkNewStart(_ header: String) -> Int? {
        guard let plus = header.range(of: "+") else { return nil }
        let digits = header[plus.upperBound...].prefix { $0.isNumber }
        return Int(digits)
    }

    // MARK: - Block detection

    /// Maximal runs of consecutive non-blank lines (1-based, inclusive),
    /// treating a fenced code block as a single block even when it contains
    /// blank lines.
    private static func blockRanges(in lines: [String]) -> [(start: Int, end: Int)] {
        var blocks: [(start: Int, end: Int)] = []
        var i = 0
        while i < lines.count {
            if isBlank(lines[i]) { i += 1; continue }
            let start = i
            var fence: String?
            while i < lines.count {
                if let marker = fenceMarker(lines[i]) {
                    if fence == nil { fence = marker }           // open
                    else if marker == fence { fence = nil }      // close
                } else if fence == nil, isBlank(lines[i]) {
                    break                                        // blank outside a fence ends the block
                }
                i += 1
            }
            blocks.append((start + 1, i)) // 0-based [start, i-1] → 1-based [start+1, i]
        }
        return blocks
    }

    private static func isBlank(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The fence marker (```` ``` ```` or `~~~`) if `line` opens or closes a fence.
    private static func fenceMarker(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("```") { return "```" }
        if trimmed.hasPrefix("~~~") { return "~~~" }
        return nil
    }
}
