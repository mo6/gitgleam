import XCTest
@testable import Gitgleam

final class RepoConfigTests: XCTestCase {
    func testCodableRoundTrip() throws {
        let repo = RepoConfig(path: "/tmp/some-repo", label: "Some Repo")
        let data = try JSONEncoder().encode(repo)
        let decoded = try JSONDecoder().decode(RepoConfig.self, from: data)
        XCTAssertEqual(decoded, repo)
    }

    func testIdentityIsStableAcrossPathAndLabelEdits() {
        var repo = RepoConfig(path: "/tmp/a", label: "A")
        let id = repo.id
        repo.path = "/tmp/b"
        repo.label = "B"
        XCTAssertEqual(repo.id, id)
    }
}
