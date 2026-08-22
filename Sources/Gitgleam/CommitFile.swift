import Foundation

/// One file changed by a commit, from `git show --name-status`.
///
/// `Codable` + `Hashable` so it can back a `List` selection in the commit
/// detail split view.
struct CommitFile: Identifiable, Hashable, Codable {
    /// The name-status code, e.g. "M", "A", "D", "R100", "C75".
    let status: String
    /// Path of the file (the new path for renames/copies).
    let path: String

    var id: String { status + path }

    /// The leading status letter (M/A/D/R/C/T…), without any similarity score.
    var statusLetter: String { String(status.prefix(1)) }

    /// The last path component, for a compact sidebar label.
    var fileName: String { (path as NSString).lastPathComponent }

    /// Human-readable description of the status.
    var statusDescription: String {
        switch statusLetter {
        case "M": return L10n.modified
        case "A": return L10n.added
        case "D": return L10n.deleted
        case "R": return L10n.renamed
        case "C": return L10n.copied
        default: return status
        }
    }

    /// Parses one `git show --name-status` line: a status code, then one path
    /// (or, for renames/copies, an old and a new path) separated by tabs. The
    /// last field is the current path.
    init?(nameStatusLine line: String) {
        let fields = line.components(separatedBy: "\t")
        guard fields.count >= 2, let last = fields.last else { return nil }
        self.status = fields[0]

        // Porcelain wraps paths with special characters in double quotes.
        var p = last
        if p.count >= 2, p.hasPrefix("\""), p.hasSuffix("\"") {
            p = String(p.dropFirst().dropLast())
        }
        self.path = p
    }
}
