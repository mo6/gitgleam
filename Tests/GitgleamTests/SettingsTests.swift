import XCTest
@testable import Gitgleam

@MainActor
final class SettingsTests: XCTestCase {
    /// A fresh, isolated `UserDefaults` suite per test so persistence tests
    /// don't leak into each other or the real `nl.mo6.gitgleam.*` prefs.
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "SettingsTests.\(UUID().uuidString)")!
    }

    private func parse(_ args: [String]) -> AppConfig {
        AppConfig.parse(["Gitgleam"] + args)
    }

    // MARK: - Seeding from AppConfig

    func testSeedsFromConfigWhenNothingStored() {
        let config = parse(["--warn", "3", "--critical", "8", "--commits", "7", "-V", "/opt/viewmd.sh"])
        let settings = Settings(config: config, defaults: freshDefaults())

        XCTAssertEqual(settings.warnThreshold, 3)
        XCTAssertEqual(settings.criticalThreshold, 8)
        XCTAssertEqual(settings.commits, 7)
        XCTAssertEqual(settings.viewmdPath, "/opt/viewmd.sh")
        XCTAssertEqual(settings.defaultView, .preview)
        XCTAssertFalse(settings.debugKeepPreviewFiles)
    }

    func testNoViewmdPathSeedsEmptyString() {
        let settings = Settings(config: parse([]), defaults: freshDefaults())
        XCTAssertEqual(settings.viewmdPath, "")
        XCTAssertNil(settings.previewSettings)
    }

    // MARK: - Persistence

    func testChangesPersistAcrossInstancesForTheSamePath() {
        let config = parse(["--path", "/tmp/some-repo"])
        let defaults = freshDefaults()

        let first = Settings(config: config, defaults: defaults)
        first.warnThreshold = 4
        first.viewmdPath = "/opt/viewmd.sh"

        let second = Settings(config: config, defaults: defaults)
        XCTAssertEqual(second.warnThreshold, 4)
        XCTAssertEqual(second.viewmdPath, "/opt/viewmd.sh")
    }

    func testDifferentPathsDoNotShareSettings() {
        let defaults = freshDefaults()
        let a = Settings(config: parse(["--path", "/tmp/repo-a"]), defaults: defaults)
        a.warnThreshold = 9

        let b = Settings(config: parse(["--path", "/tmp/repo-b"]), defaults: defaults)
        XCTAssertEqual(b.warnThreshold, 1) // untouched default, not repo-a's 9
    }

    // MARK: - Clamping (live edits, mirroring AppConfig's own clamp rules)

    func testWarnThresholdFloorsAtOne() {
        let settings = Settings(config: parse([]), defaults: freshDefaults())
        settings.warnThreshold = 0
        XCTAssertEqual(settings.warnThreshold, 1)
    }

    func testRefreshIntervalClampsToConfiguredRange() {
        let settings = Settings(config: parse([]), defaults: freshDefaults())
        settings.refreshInterval = 1
        XCTAssertEqual(settings.refreshInterval, AppConfig.minInterval)
        settings.refreshInterval = 9999
        XCTAssertEqual(settings.refreshInterval, AppConfig.maxInterval)
    }

    func testPreviewWidthFloorsAtTwenty() {
        let settings = Settings(config: parse([]), defaults: freshDefaults())
        settings.previewWidth = 5
        XCTAssertEqual(settings.previewWidth, 20)
    }

    // MARK: - previewSettings / debug flag

    func testPreviewSettingsReflectsDebugKeepFiles() throws {
        let settings = Settings(config: parse(["-V", "/opt/viewmd.sh"]), defaults: freshDefaults())
        settings.debugKeepPreviewFiles = true
        let preview = try XCTUnwrap(settings.previewSettings)
        XCTAssertTrue(preview.debugKeepFiles)
    }

    func testBlankViewmdPathDisablesPreview() {
        let settings = Settings(config: parse([]), defaults: freshDefaults())
        settings.viewmdPath = "   "
        XCTAssertNil(settings.previewSettings)
    }
}
