import Foundation
import XCTest

/// The vendored WebPreview JS is not a SwiftPM package, so Dependabot/npm
/// audit track it via `scripts/webpreview/package.json`. These tests keep
/// NOTICE.txt, that pin, and `marked.min.js`'s header in lockstep — `npm
/// audit` itself runs in CI (`scripts/check-webpreview-deps.sh`), not here.
final class WebPreviewDependencyTests: XCTestCase {
    func testNoticeMatchesNpmPins() throws {
        let pins = try npmPins()
        let notice = try String(contentsOf: webPreview.appendingPathComponent("NOTICE.txt"), encoding: .utf8)
        XCTAssertTrue(notice.contains("marked \(pins.marked) "), "NOTICE.txt should pin marked \(pins.marked)")
        XCTAssertTrue(notice.contains("mermaid \(pins.mermaid) "), "NOTICE.txt should pin mermaid \(pins.mermaid)")
    }

    func testMarkedMinJsHeaderMatchesPin() throws {
        let pins = try npmPins()
        let header = try String(contentsOf: webPreview.appendingPathComponent("marked.min.js"), encoding: .utf8)
        XCTAssertTrue(
            header.contains("marked v\(pins.marked)"),
            "marked.min.js header should contain marked v\(pins.marked); re-run scripts/vendor-webpreview.sh"
        )
    }

    func testMermaidMinJsEmbedsPin() throws {
        let pins = try npmPins()
        let js = try String(contentsOf: webPreview.appendingPathComponent("mermaid.min.js"), encoding: .utf8)
        XCTAssertTrue(
            js.contains("version:\"\(pins.mermaid)\""),
            "mermaid.min.js should embed version:\"\(pins.mermaid)\"; re-run scripts/vendor-webpreview.sh"
        )
    }

    func testThirdPartyNoticesMatchesPins() throws {
        let pins = try npmPins()
        let notices = try String(
            contentsOf: repoRoot.appendingPathComponent("THIRD_PARTY_NOTICES.md"), encoding: .utf8
        )
        XCTAssertTrue(notices.contains("## marked \(pins.marked)\n"), "THIRD_PARTY_NOTICES.md should heading-pin marked")
        XCTAssertTrue(notices.contains("## mermaid \(pins.mermaid)\n"), "THIRD_PARTY_NOTICES.md should heading-pin mermaid")
    }

    // MARK: - Paths

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // GitgleamTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo
    }

    private var webPreview: URL {
        repoRoot.appendingPathComponent("Sources/Gitgleam/WebPreview")
    }

    private func npmPins() throws -> (marked: String, mermaid: String) {
        let url = repoRoot.appendingPathComponent("scripts/webpreview/package.json")
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let deps = json?["dependencies"] as? [String: String]
        let marked = try XCTUnwrap(deps?["marked"])
        let mermaid = try XCTUnwrap(deps?["mermaid"])
        return (marked, mermaid)
    }
}
