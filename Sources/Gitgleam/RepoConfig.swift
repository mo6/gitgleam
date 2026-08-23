import Foundation

/// One watched repository: a path plus a display label, as configured in
/// Settings' Repositories tab.
///
/// `id` is generated once and stays stable across edits (path/label can both
/// change without losing the repo's identity), which is what lets `AppMonitor`
/// reuse or discard `RepoMonitor`s correctly and lets open diff/commit windows
/// keep referring to the right repo.
///
/// New fields (`isEnabled`, per-repo thresholds) are decoded with defaults so
/// settings persisted before they existed still load — see `init(from:)`.
struct RepoConfig: Identifiable, Codable, Hashable {
    let id: UUID
    var path: String
    var label: String
    /// When false the repo stays in the list (and the menu) but `AppMonitor`
    /// does not watch it — no FSEvents stream, no poll, no `git status`.
    var isEnabled: Bool
    /// Per-repo warn threshold, or `nil` to use `Settings.warnThreshold`.
    var warnThreshold: Int?
    /// Per-repo critical threshold, or `nil` to use `Settings.criticalThreshold`.
    var criticalThreshold: Int?

    init(
        id: UUID = UUID(),
        path: String,
        label: String,
        isEnabled: Bool = true,
        warnThreshold: Int? = nil,
        criticalThreshold: Int? = nil
    ) {
        self.id = id
        self.path = path
        self.label = label
        self.isEnabled = isEnabled
        self.warnThreshold = warnThreshold
        self.criticalThreshold = criticalThreshold
    }

    /// Canonical path used to detect duplicates (symlinks, `..`, trailing slashes).
    static func standardizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
    }

    /// True when `path` is already used by another entry in `repos`.
    static func isDuplicate(_ path: String, among repos: [RepoConfig], excluding id: UUID? = nil) -> Bool {
        let mine = standardizedPath(path)
        return repos.contains { repo in
            if let id, repo.id == id { return false }
            return standardizedPath(repo.path) == mine
        }
    }

    /// A folder looks like a git repo when it contains a `.git` file or directory
    /// (a file is how git worktrees / submodules record their gitdir).
    static func looksLikeGitRepository(at path: String) -> Bool {
        FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent(".git"))
    }

    enum CodingKeys: String, CodingKey {
        case id, path, label, isEnabled, warnThreshold, criticalThreshold
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        path = try c.decode(String.self, forKey: .path)
        label = try c.decode(String.self, forKey: .label)
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        warnThreshold = try c.decodeIfPresent(Int.self, forKey: .warnThreshold)
        criticalThreshold = try c.decodeIfPresent(Int.self, forKey: .criticalThreshold)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(path, forKey: .path)
        try c.encode(label, forKey: .label)
        try c.encode(isEnabled, forKey: .isEnabled)
        try c.encodeIfPresent(warnThreshold, forKey: .warnThreshold)
        try c.encodeIfPresent(criticalThreshold, forKey: .criticalThreshold)
    }
}
