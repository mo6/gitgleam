import Foundation

/// One changed file from `git status --porcelain`.
///
/// `Codable` + `Hashable` so a `FileChange` can be passed as a value to a
/// `WindowGroup` to open the diff window.
struct FileChange: Identifiable, Hashable, Codable {
    /// The XY status code, e.g. " M", "??", "A ", "R ".
    let status: String
    /// Path of the file, relative to the repository.
    let path: String

    var id: String { status + path }

    /// Untracked files (`??`) are not yet in git; their diff is handled
    /// differently (compared against /dev/null).
    var isUntracked: Bool { status.trimmingCharacters(in: .whitespaces) == "??" }

    /// Coarse grouping for the menu sections.
    enum Category {
        case changed // modified, renamed, copied, conflict
        case new     // untracked or staged add
        case deleted // deleted
    }

    /// Derives the category from the porcelain status code.
    ///
    /// Order is deliberate: untracked first, then a 'D' (deleted), then an 'A'
    /// (added), otherwise "changed". This keeps the exceptional `AD` (added and
    /// deleted) on the deleted side — harmless for a working copy.
    var category: Category {
        let code = status.trimmingCharacters(in: .whitespaces)
        if code == "??" { return .new }
        if code.contains("D") { return .deleted }
        if code.contains("A") { return .new }
        return .changed
    }

    /// Human-readable description of the status for the window header.
    var statusDescription: String {
        switch status.trimmingCharacters(in: .whitespaces) {
        case "M", "MM", "AM", "RM": return L10n.modified
        case "A", "AD": return L10n.added
        case "D": return L10n.deleted
        case "R": return L10n.renamed
        case "C": return L10n.copied
        case "U", "UU", "AA", "DD": return L10n.conflict
        case "??": return L10n.newUntracked
        default: return status
        }
    }

    /// Parses one line of porcelain output (`XY PATH`) into a `FileChange`.
    ///
    /// Note: this covers the common cases. Renames are shown at their new path;
    /// paths with special characters that git wraps in double quotes are simply
    /// stripped of those quotes.
    init?(porcelainLine line: String) {
        // Minimum: 2 status characters + space + 1 char of path.
        guard line.count >= 4 else { return nil }

        let statusEnd = line.index(line.startIndex, offsetBy: 2)
        self.status = String(line[..<statusEnd])

        // Path starts after the status code and the separating space.
        var rest = String(line[line.index(statusEnd, offsetBy: 1)...])

        // Renamed/copied: "old -> new" → show the new path.
        if let arrow = rest.range(of: " -> ") {
            rest = String(rest[arrow.upperBound...])
        }

        // Porcelain wraps paths with special characters in double quotes.
        if rest.count >= 2, rest.hasPrefix("\""), rest.hasSuffix("\"") {
            rest = String(rest.dropFirst().dropLast())
        }

        self.path = rest
    }
}
