import Foundation

/// A `Commit` bundled with which repository it belongs to.
///
/// `Commit` itself stays a pure parse model (used as-is by `Git`,
/// `ColoredDiffView`, etc.); this wrapper is only what travels through
/// `openWindow(id:value:)` so the commit-detail window knows which repo's
/// history to read, now that several repos can be open at once.
struct RepoCommit: Identifiable, Hashable, Codable {
    let repoID: UUID
    let repoPath: String
    let commit: Commit

    var id: String { repoID.uuidString + commit.id }
}
