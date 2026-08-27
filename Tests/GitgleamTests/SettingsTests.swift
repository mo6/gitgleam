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
        // Only the repo list and viewmd path are still CLI-seedable —
        // everything else has no flag at all and always starts at
        // AppConfig's own default constants (see AppConfig's doc comment).
        let config = parse(["-V", "/opt/viewmd.sh"])
        let settings = Settings(config: config, defaults: freshDefaults())

        XCTAssertEqual(settings.warnThreshold, AppConfig.defaultWarnThreshold)
        XCTAssertEqual(settings.criticalThreshold, AppConfig.defaultCriticalThreshold)
        XCTAssertEqual(settings.commits, AppConfig.defaultCommits)
        XCTAssertEqual(settings.viewmdPath, "/opt/viewmd.sh")
        XCTAssertEqual(settings.defaultView, .preview)
        XCTAssertFalse(settings.debugKeepPreviewFiles)
        XCTAssertEqual(settings.language, "auto") // no CLI flag for it
        XCTAssertEqual(settings.repos, config.initialRepos)
        XCTAssertTrue(settings.showOpenInFinder) // no CLI flag for it either
        XCTAssertTrue(settings.showOpenInTerminal)
        XCTAssertTrue(settings.wrapDiffLines) // no CLI flag for it either
    }

    func testLanguagePersistsAcrossInstances() {
        let config = parse([])
        let defaults = freshDefaults()

        let first = Settings(config: config, defaults: defaults)
        first.language = "nl"

        let second = Settings(config: config, defaults: defaults)
        XCTAssertEqual(second.language, "nl")
    }

    func testDataWithoutLanguageOrReposKeysStillDecodes() {
        // Simulates settings persisted before `language`/`repos` existed: the
        // rest of the stored values must still load, with language defaulting
        // to "auto" and repos migrating in from `config.initialRepos`, rather
        // than the whole decode failing.
        let config = parse(["--path", "/tmp/legacy-repo"])
        let defaults = freshDefaults()
        let legacyJSON = """
        {"warnThreshold":4,"criticalThreshold":10,"refreshInterval":60,"maxEntries":25,
         "commits":10,"viewmdPath":"","defaultView":"preview","previewWidth":100,
         "debugKeepPreviewFiles":false}
        """
        // The pre-multi-repo storage key: `"nl.mo6.gitgleam.settings.<path>"`,
        // one blob per watched path.
        defaults.set(Data(legacyJSON.utf8), forKey: "nl.mo6.gitgleam.settings./tmp/legacy-repo")

        let settings = Settings(config: config, defaults: defaults)
        XCTAssertEqual(settings.language, "auto")
        XCTAssertEqual(settings.warnThreshold, 4) // the rest of the legacy data still loaded
        XCTAssertEqual(settings.repos, config.initialRepos) // the one repo migrates in
        XCTAssertTrue(settings.showOpenInFinder) // absent from the legacy blob too
        XCTAssertTrue(settings.showOpenInTerminal)
        XCTAssertTrue(settings.wrapDiffLines) // absent from the legacy blob too
    }

    func testOpenInFinderAndTerminalTogglesPersistAcrossInstances() {
        let config = parse([])
        let defaults = freshDefaults()

        let first = Settings(config: config, defaults: defaults)
        first.showOpenInFinder = false
        first.showOpenInTerminal = false

        let second = Settings(config: config, defaults: defaults)
        XCTAssertFalse(second.showOpenInFinder)
        XCTAssertFalse(second.showOpenInTerminal)
    }

    func testWrapDiffLinesPersistsAcrossInstances() {
        let config = parse([])
        let defaults = freshDefaults()

        let first = Settings(config: config, defaults: defaults)
        first.wrapDiffLines = false

        let second = Settings(config: config, defaults: defaults)
        XCTAssertFalse(second.wrapDiffLines)
    }

    func testNoViewmdPathSeedsEmptyString() {
        let settings = Settings(config: parse([]), defaults: freshDefaults())
        XCTAssertEqual(settings.viewmdPath, "")
        XCTAssertNil(settings.previewSettings)
    }

    // MARK: - Persistence

    func testChangesPersistAcrossInstances() {
        let config = parse(["--path", "/tmp/some-repo"])
        let defaults = freshDefaults()

        let first = Settings(config: config, defaults: defaults)
        first.warnThreshold = 4
        first.viewmdPath = "/opt/viewmd.sh"

        let second = Settings(config: config, defaults: defaults)
        XCTAssertEqual(second.warnThreshold, 4)
        XCTAssertEqual(second.viewmdPath, "/opt/viewmd.sh")
    }

    func testDefaultViewWebPersistsAcrossInstances() {
        let defaults = freshDefaults()
        let first = Settings(config: parse([]), defaults: defaults)
        first.defaultView = .web

        let second = Settings(config: parse([]), defaults: defaults)
        XCTAssertEqual(second.defaultView, .web)
    }

    func testReposPersistAcrossInstances() {
        let defaults = freshDefaults()
        let first = Settings(config: parse([]), defaults: defaults)
        first.repos = [
            RepoConfig(path: "/tmp/a", label: "A", isEnabled: false, warnThreshold: 2, criticalThreshold: 9),
            RepoConfig(path: "/tmp/b", label: "B"),
        ]

        let second = Settings(config: parse([]), defaults: defaults)
        XCTAssertEqual(second.repos, first.repos)
        XCTAssertFalse(second.repos[0].isEnabled)
        XCTAssertEqual(second.repos[0].warnThreshold, 2)
        XCTAssertTrue(second.repos[1].isEnabled)
        XCTAssertNil(second.repos[1].warnThreshold)
    }

    func testExportImportRoundTrip() throws {
        let first = Settings(config: parse(["-V", "/opt/viewmd.sh"]), defaults: freshDefaults())
        first.language = "nl"
        first.warnThreshold = 4
        first.repos = [RepoConfig(path: "/tmp/a", label: "A", isEnabled: false)]
        let data = try first.exportedJSON()

        let second = Settings(config: parse([]), defaults: freshDefaults())
        try second.importJSON(data)
        XCTAssertEqual(second.language, "nl")
        XCTAssertEqual(second.warnThreshold, 4)
        XCTAssertEqual(second.viewmdPath, "/opt/viewmd.sh")
        XCTAssertEqual(second.repos, first.repos)
    }

    func testImportRejectsInvalidJSON() {
        let settings = Settings(config: parse([]), defaults: freshDefaults())
        XCTAssertThrowsError(try settings.importJSON(Data("not-json".utf8)))
    }

    func testSettingsAreSharedGloballyRegardlessOfInitialLaunchPath() {
        // Storage is keyed globally now (one process, many repos), not per
        // watched path: a later launch with a different --path still sees
        // the same thresholds, since there is only ever one settings blob.
        let defaults = freshDefaults()
        let a = Settings(config: parse(["--path", "/tmp/repo-a"]), defaults: defaults)
        a.warnThreshold = 9

        let b = Settings(config: parse(["--path", "/tmp/repo-b"]), defaults: defaults)
        XCTAssertEqual(b.warnThreshold, 9)
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
