import Foundation

/// A `FileChange` bundled with which repository it belongs to.
///
/// `FileChange` itself stays a pure parse model (used as-is by `Git`,
/// `ColoredDiffView`, etc.); this wrapper is only what travels through
/// `openWindow(id:value:)` so the diff window knows which repo's working tree
/// to read, now that several repos can be open at once.
struct RepoFileChange: Identifiable, Hashable, Codable {
    let repoID: UUID
    let repoPath: String
    let change: FileChange

    var id: String { repoID.uuidString + change.id }
}

/// A `Commit` bundled with which repository it belongs to. Mirrors
/// `RepoFileChange` for the commit-detail window.
struct RepoCommit: Identifiable, Hashable, Codable {
    let repoID: UUID
    let repoPath: String
    let commit: Commit

    var id: String { repoID.uuidString + commit.id }
}
