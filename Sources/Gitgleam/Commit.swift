import Foundation

/// One entry from `git log`.
///
/// `Codable` + `Hashable` so a `Commit` can be passed as a value to a
/// `WindowGroup` to open its detail window (mirrors `FileChange`).
struct Commit: Identifiable, Hashable, Codable {
    /// Full commit hash.
    let sha: String
    /// Abbreviated hash, shown in the menu and window title.
    let shortSHA: String
    /// First line of the commit message.
    let subject: String
    /// Author name.
    let author: String
    /// Human-readable relative date, e.g. "2 hours ago".
    let relativeDate: String
    /// Absolute commit date/time, e.g. "2026-08-20 19:12".
    let date: String

    var id: String { sha }

    /// Field separator used in the `git log` format string. The unit-separator
    /// control character is safe: it never appears in commit metadata.
    static let fieldSeparator = "\u{1f}"

    /// Parses one `git log` record whose fields are joined by `fieldSeparator`
    /// in the order: full hash, short hash, subject, author, relative date,
    /// absolute date/time.
    init?(logLine line: String) {
        let fields = line.components(separatedBy: Commit.fieldSeparator)
        guard fields.count == 6 else { return nil }
        self.sha = fields[0]
        self.shortSHA = fields[1]
        self.subject = fields[2]
        self.author = fields[3]
        self.relativeDate = fields[4]
        self.date = fields[5]
    }
}
