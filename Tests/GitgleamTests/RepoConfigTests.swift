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

    func testLegacyJSONWithoutNewFieldsDefaultsToEnabledAndSharedThresholds() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","path":"/tmp/a","label":"A"}
        """
        let decoded = try JSONDecoder().decode(RepoConfig.self, from: Data(json.utf8))
        XCTAssertTrue(decoded.isEnabled)
        XCTAssertNil(decoded.warnThreshold)
        XCTAssertNil(decoded.criticalThreshold)
        XCTAssertEqual(decoded.path, "/tmp/a")
        XCTAssertEqual(decoded.label, "A")
    }

    func testDuplicatePathsIgnoreTrailingSlash() {
        let a = RepoConfig(path: "/tmp/gitgleam-dup-a", label: "A")
        XCTAssertTrue(RepoConfig.isDuplicate("/tmp/gitgleam-dup-a/", among: [a], excluding: UUID()))
        XCTAssertFalse(RepoConfig.isDuplicate("/tmp/gitgleam-dup-a", among: [a], excluding: a.id))
        XCTAssertFalse(RepoConfig.isDuplicate("/tmp/gitgleam-dup-b", among: [a]))
    }
}
