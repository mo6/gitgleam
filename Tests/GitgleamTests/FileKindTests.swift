import XCTest
@testable import Gitgleam

final class FileKindTests: XCTestCase {
    func testMarkdownExtensions() {
        XCTAssertTrue(FileKind.isMarkdown("notes.md"))
        XCTAssertTrue(FileKind.isMarkdown("README.markdown"))
        XCTAssertTrue(FileKind.isMarkdown("a.mkd"))
        XCTAssertTrue(FileKind.isMarkdown("a.mdown"))
        XCTAssertTrue(FileKind.isMarkdown("path/to/deep/file.md"))
    }

    func testCaseInsensitive() {
        XCTAssertTrue(FileKind.isMarkdown("NOTES.MD"))
        XCTAssertTrue(FileKind.isMarkdown("Read.MarkDown"))
    }

    func testNonMarkdown() {
        XCTAssertFalse(FileKind.isMarkdown("main.swift"))
        XCTAssertFalse(FileKind.isMarkdown("notes.txt"))
        XCTAssertFalse(FileKind.isMarkdown("Makefile"))          // no extension
        XCTAssertFalse(FileKind.isMarkdown("archive.md.zip"))    // extension is zip
        XCTAssertFalse(FileKind.isMarkdown("README"))
    }
}
