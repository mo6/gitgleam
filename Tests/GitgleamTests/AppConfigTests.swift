import XCTest
@testable import Gitgleam

final class AppConfigTests: XCTestCase {
    /// arguments[0] is the executable path; real flags start at index 1.
    private func parse(_ args: [String]) -> AppConfig {
        AppConfig.parse(["Gitgleam"] + args)
    }

    // MARK: - viewmd flag

    func testViewmdPathUnsetByDefault() {
        let c = parse([])
        XCTAssertNil(c.viewmdPath)
    }

    func testViewmdPathIsRecorded() {
        let c = parse(["--viewmd-path", "/opt/viewmd/viewmd.sh"])
        XCTAssertEqual(c.viewmdPath, "/opt/viewmd/viewmd.sh")
    }

    func testViewmdPathTildeIsExpanded() {
        let c = parse(["-V", "~/tools/viewmd.sh"])
        let path = c.viewmdPath ?? ""
        XCTAssertTrue(path.hasPrefix("/"), "expected an absolute path, got \(path)")
        XCTAssertFalse(path.contains("~"))
    }

    func testEmptyViewmdPathStaysNil() {
        let c = parse(["--viewmd-path", ""])
        XCTAssertNil(c.viewmdPath)
    }

    // MARK: - Repo list

    func testNoFlagsYieldsOneRepoAtCurrentDirectory() {
        let c = parse([])
        XCTAssertEqual(c.initialRepos.count, 1)
        XCTAssertEqual(c.initialRepos[0].path, FileManager.default.currentDirectoryPath)
    }

    func testPathAndLabelSynthesizeOneRepo() {
        let c = parse(["--path", "/tmp/some-repo", "--label", "Brain"])
        XCTAssertEqual(c.initialRepos.count, 1)
        XCTAssertEqual(c.initialRepos[0].path, "/tmp/some-repo")
        XCTAssertEqual(c.initialRepos[0].label, "Brain")
    }

    func testEmptyLabelFallsBackToLastPathComponent() {
        let c = parse(["--path", "/tmp/some-repo", "--label", ""])
        XCTAssertEqual(c.initialRepos[0].label, "some-repo")
    }

    func testRepeatableRepoFlagBuildsMultipleRepos() {
        let c = parse(["--repo", "/tmp/a:A", "--repo", "/tmp/b:B"])
        XCTAssertEqual(c.initialRepos.map(\.path), ["/tmp/a", "/tmp/b"])
        XCTAssertEqual(c.initialRepos.map(\.label), ["A", "B"])
    }

    func testRepoFlagWithoutLabelUsesLastPathComponent() {
        let c = parse(["--repo", "/tmp/some-repo"])
        XCTAssertEqual(c.initialRepos[0].label, "some-repo")
    }

    func testRepoFlagTakesPrecedenceOverPath() {
        let c = parse(["--repo", "/tmp/a", "--path", "/tmp/ignored"])
        XCTAssertEqual(c.initialRepos.map(\.path), ["/tmp/a"])
    }

    func testRepoFlagTildeIsExpanded() {
        let c = parse(["--repo", "~/tools:Tools"])
        XCTAssertTrue(c.initialRepos[0].path.hasPrefix("/"))
        XCTAssertFalse(c.initialRepos[0].path.contains("~"))
    }

    // MARK: - Unknown flags

    func testRemovedFlagsAreIgnoredNotCrashing() {
        // --warn/--critical/--interval/--commits/--default-view/
        // --preview-width used to be CLI flags; they're Settings-only now
        // (see AppConfig's doc comment), so parsing must silently ignore
        // them rather than crash or misparse the repo list around them.
        let c = parse(["--warn", "3", "--repo", "/tmp/a", "--commits", "7"])
        XCTAssertEqual(c.initialRepos.map(\.path), ["/tmp/a"])
    }
}
