import XCTest
@testable import Gitgleam

final class ViewModeTests: XCTestCase {
    func testNonMarkdownIsAlwaysDiff() {
        XCTAssertEqual(ViewMode.initial(preferred: .web, isMarkdown: false, hasViewmd: true), .diff)
        XCTAssertEqual(ViewMode.initial(preferred: .preview, isMarkdown: false, hasViewmd: true), .diff)
        XCTAssertEqual(ViewMode.initial(preferred: .diff, isMarkdown: false, hasViewmd: true), .diff)
    }

    func testNonMarkdownCanPreferDiffFull() {
        XCTAssertEqual(ViewMode.initial(preferred: .diffFull, isMarkdown: false, hasViewmd: true), .diffFull)
        XCTAssertEqual(ViewMode.initial(preferred: .diffFull, isMarkdown: false, hasViewmd: false), .diffFull)
    }

    func testPreferredDiff() {
        XCTAssertEqual(ViewMode.initial(preferred: .diff, isMarkdown: true, hasViewmd: true), .diff)
        XCTAssertEqual(ViewMode.initial(preferred: .diff, isMarkdown: true, hasViewmd: false), .diff)
    }

    func testPreferredDiffFull() {
        XCTAssertEqual(ViewMode.initial(preferred: .diffFull, isMarkdown: true, hasViewmd: true), .diffFull)
        XCTAssertEqual(ViewMode.initial(preferred: .diffFull, isMarkdown: true, hasViewmd: false), .diffFull)
    }

    func testPreferredWeb() {
        XCTAssertEqual(ViewMode.initial(preferred: .web, isMarkdown: true, hasViewmd: true), .web)
        XCTAssertEqual(ViewMode.initial(preferred: .web, isMarkdown: true, hasViewmd: false), .web)
    }

    func testPreferredPreviewFallsBackToWebWithoutViewmd() {
        XCTAssertEqual(ViewMode.initial(preferred: .preview, isMarkdown: true, hasViewmd: true), .preview)
        XCTAssertEqual(ViewMode.initial(preferred: .preview, isMarkdown: true, hasViewmd: false), .web)
    }
}
