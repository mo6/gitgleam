import Foundation

/// One watched repository: a path plus a display label, as configured in
/// Settings' Repositories tab.
///
/// `id` is generated once and stays stable across edits (path/label can both
/// change without losing the repo's identity), which is what lets `AppMonitor`
/// reuse or discard `RepoMonitor`s correctly and lets open diff/commit windows
/// keep referring to the right repo.
struct RepoConfig: Identifiable, Codable, Hashable {
    let id: UUID
    var path: String
    var label: String

    init(id: UUID = UUID(), path: String, label: String) {
        self.id = id
        self.path = path
        self.label = label
    }
}
