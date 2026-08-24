import XCTest
@testable import Gitgleam

final class AppConfigTests: XCTestCase {
    /// arguments[0] is the executable path; real flags start at index 1.
    private func parse(_ args: [String]) -> AppConfig {
        AppConfig.parse(["Gitgleam"] + args)
    }

    // MARK: - Defaults

    func testPreviewDisabledByDefault() {
        let c = parse([])
        XCTAssertNil(c.viewmdPath)
        XCTAssertNil(c.previewSettings)          // no viewmd path ⇒ diff only
        XCTAssertNil(c.defaultView)
        XCTAssertEqual(c.previewWidth, AppConfig.defaultPreviewWidth)
    }

    // MARK: - viewmd / preview flags

    func testViewmdPathEnablesPreviewDefaultingToPreview() throws {
        let c = parse(["--viewmd-path", "/opt/viewmd/viewmd.sh"])
        XCTAssertEqual(c.viewmdPath, "/opt/viewmd/viewmd.sh")
        let settings = try XCTUnwrap(c.previewSettings)
        XCTAssertEqual(settings.viewmdPath, "/opt/viewmd/viewmd.sh")
        XCTAssertEqual(settings.defaultView, .preview)   // default once configured
        XCTAssertEqual(settings.width, AppConfig.defaultPreviewWidth)
    }

    func testDefaultViewDiffOverride() {
        let c = parse(["-V", "/opt/viewmd/viewmd.sh", "--default-view", "diff"])
        XCTAssertEqual(c.defaultView, .diff)
        XCTAssertEqual(c.previewSettings?.defaultView, .diff)
    }

    func testDefaultViewWithoutViewmdPathStaysDisabled() {
        // --default-view is recorded, but with no viewmd path there is no preview.
        let c = parse(["--default-view", "preview"])
        XCTAssertEqual(c.defaultView, .preview)
        XCTAssertNil(c.previewSettings)
    }

    func testInvalidDefaultViewIsIgnored() {
        let c = parse(["-V", "/x/viewmd.sh", "--default-view", "sideways"])
        XCTAssertNil(c.defaultView)                        // unparseable ⇒ nil
        XCTAssertEqual(c.previewSettings?.defaultView, .preview)
    }

    func testViewmdPathTildeIsExpanded() {
        let c = parse(["-V", "~/tools/viewmd.sh"])
        let path = c.viewmdPath ?? ""
        XCTAssertTrue(path.hasPrefix("/"), "expected an absolute path, got \(path)")
        XCTAssertFalse(path.contains("~"))
    }

    func testEmptyViewmdPathDisablesPreview() {
        let c = parse(["--viewmd-path", ""])
        XCTAssertNil(c.viewmdPath)
        XCTAssertNil(c.previewSettings)
    }

    func testPreviewWidthClamp() {
        XCTAssertEqual(parse(["--preview-width", "40"]).previewWidth, 40)
        XCTAssertEqual(parse(["--preview-width", "5"]).previewWidth, 20)   // floor
    }

    // MARK: - Existing flags still behave

    func testThresholdsAndClamps() {
        // warn floors at 1; critical is raised to at least warn.
        let c = parse(["--warn", "0", "--critical", "-3"])
        XCTAssertEqual(c.warnThreshold, 1)
        XCTAssertEqual(c.criticalThreshold, 1)

        let c2 = parse(["--warn", "5", "--critical", "2"])
        XCTAssertEqual(c2.criticalThreshold, 5)  // max(warn, critical)
    }

    func testIntervalClamp() {
        XCTAssertEqual(parse(["--interval", "5"]).refreshInterval, AppConfig.minInterval)
        XCTAssertEqual(parse(["--interval", "9999"]).refreshInterval, AppConfig.maxInterval)
    }

    func testCommitFloor() {
        XCTAssertEqual(parse(["--commits", "0"]).commits, 1)
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
}
