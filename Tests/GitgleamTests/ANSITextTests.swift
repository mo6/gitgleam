import SwiftUI
import XCTest
@testable import Gitgleam

/// Tests for the ANSI/SGR → `AttributedString` parser.
final class ANSITextTests: XCTestCase {
    /// A run's plain text, foreground color, and whether it is struck through.
    private struct Run: Equatable {
        let text: String
        let color: Color?
        let strike: Bool
    }

    private func runs(_ ansi: String) -> [Run] {
        let s = ANSIText.attributed(from: ansi)
        return s.runs.map { run in
            Run(text: String(s[run.range].characters),
                color: run.foregroundColor,
                strike: run.strikethroughStyle != nil)
        }
    }

    private func backgroundColors(_ ansi: String) -> [Color?] {
        let s = ANSIText.attributed(from: ansi)
        return s.runs.map { $0.backgroundColor }
    }

    private func plainText(_ ansi: String) -> String {
        String(ANSIText.attributed(from: ansi).characters)
    }

    func testPlainTextIsUnchanged() {
        let text = "hello world\nsecond line"
        XCTAssertEqual(plainText(text), text)
        // No attributes on plain text.
        XCTAssertEqual(runs(text), [Run(text: text, color: nil, strike: false)])
    }

    func testBasicForegroundColor() {
        XCTAssertEqual(runs("\u{1B}[31mred\u{1B}[0m"),
                       [Run(text: "red", color: .red, strike: false)])
        XCTAssertEqual(runs("\u{1B}[32mgreen\u{1B}[0m").first?.color, .green)
        XCTAssertEqual(runs("\u{1B}[36mcyan\u{1B}[0m").first?.color, .cyan)
    }

    func testResetClearsColor() {
        // "a" is red, "b" reverts to the default (no color).
        XCTAssertEqual(runs("\u{1B}[31ma\u{1B}[0mb"),
                       [Run(text: "a", color: .red, strike: false),
                        Run(text: "b", color: nil, strike: false)])
    }

    func testEmptySGRIsReset() {
        // `ESC[m` with no parameters is equivalent to `ESC[0m`.
        XCTAssertEqual(runs("\u{1B}[31ma\u{1B}[mb").last,
                       Run(text: "b", color: nil, strike: false))
    }

    func testStrikethrough() {
        XCTAssertTrue(runs("\u{1B}[9mgone\u{1B}[0m").first?.strike == true)
        // 29 turns strikethrough back off.
        XCTAssertFalse(runs("\u{1B}[9ma\u{1B}[29mb").last?.strike == true)
    }

    func testBoldSetsAFont() {
        let s = ANSIText.attributed(from: "\u{1B}[1mbold\u{1B}[0m")
        XCTAssertNotNil(s.runs.first?.font)
    }

    func testExtended256AndTruecolorParse() {
        // Both extended-color forms strip cleanly and produce a colored run.
        XCTAssertEqual(plainText("\u{1B}[38;5;196mX\u{1B}[0m"), "X")
        XCTAssertNotNil(runs("\u{1B}[38;5;196mX\u{1B}[0m").first?.color)
        XCTAssertEqual(plainText("\u{1B}[38;2;10;20;30mY\u{1B}[0m"), "Y")
        XCTAssertNotNil(runs("\u{1B}[38;2;10;20;30mY\u{1B}[0m").first?.color)
    }

    func testBackgroundColorsDoNotLeakDigitsIntoText() {
        // A background SGR (48;5;n) must not leak digits into the text.
        XCTAssertEqual(plainText("\u{1B}[48;5;21mtext\u{1B}[0m"), "text")
    }

    func testBasicBackgroundColor() {
        XCTAssertEqual(backgroundColors("\u{1B}[41mred-bg\u{1B}[0m"), [.red])
        XCTAssertEqual(backgroundColors("\u{1B}[102mgreen-bg\u{1B}[0m"), [.green])
    }

    func testBackgroundColorReset() {
        // "a" has a background, "b" reverts after 49 (bg reset) or 0 (full reset).
        XCTAssertEqual(backgroundColors("\u{1B}[41ma\u{1B}[49mb"), [.red, nil])
        XCTAssertEqual(backgroundColors("\u{1B}[41ma\u{1B}[0mb"), [.red, nil])
    }

    func testExtendedBackgroundColorParses() {
        XCTAssertEqual(plainText("\u{1B}[48;5;196mX\u{1B}[0m"), "X")
        XCTAssertNotNil(backgroundColors("\u{1B}[48;5;196mX\u{1B}[0m").first ?? nil)
        XCTAssertEqual(plainText("\u{1B}[48;2;10;20;30mY\u{1B}[0m"), "Y")
        XCTAssertNotNil(backgroundColors("\u{1B}[48;2;10;20;30mY\u{1B}[0m").first ?? nil)
    }

    func testForegroundAndBackgroundColorTogether() {
        let s = ANSIText.attributed(from: "\u{1B}[31;42mboth\u{1B}[0m")
        XCTAssertEqual(s.runs.first?.foregroundColor, .red)
        XCTAssertEqual(s.runs.first?.backgroundColor, .green)
    }

    func testAllEscapesAreStripped() {
        let ansi = "\u{1B}[1;4mTitle\u{1B}[0m \u{1B}[2;9mdim\u{1B}[0m \u{1B}[38;5;42mx\u{1B}[0m"
        let out = plainText(ansi)
        XCTAssertFalse(out.unicodeScalars.contains { $0.value == 0x1B }, "no ESC should survive")
        XCTAssertEqual(out, "Title dim x")
    }

    func testLoneAndUnterminatedEscapesAreDropped() {
        XCTAssertEqual(plainText("a\u{1B}"), "a")            // lone ESC at end
        XCTAssertEqual(plainText("a\u{1B}[31"), "a")         // unterminated CSI
        XCTAssertEqual(plainText("a\u{1B}Xb"), "aXb")        // ESC not starting a CSI
    }

    func testNonSGRCSIsAreConsumed() {
        // A cursor-move CSI (ends in 'H') is consumed without emitting text.
        XCTAssertEqual(plainText("a\u{1B}[2Hb"), "ab")
    }

    func testOSC8HyperlinksAreStrippedKeepingLabel() {
        let st = "\u{1B}\\"   // ST terminator (ESC \)
        let bel = "\u{07}"    // BEL terminator
        // ST-terminated OSC 8, as viewmd emits for a TOC entry.
        let toc = "\u{1B}]8;id=1;viewmd-toc:0:Context\(st)Context\u{1B}]8;;\(st)"
        XCTAssertEqual(plainText(toc), "Context")
        // BEL-terminated form.
        let link = "\u{1B}]8;;http://example.com\(bel)label\u{1B}]8;;\(bel)"
        XCTAssertEqual(plainText(link), "label")
        // A colored label keeps its color once the OSC wrappers are gone.
        let colored = "\u{1B}]8;;u\(st)\u{1B}[35mText\u{1B}[0m\u{1B}]8;;\(st)"
        XCTAssertEqual(runs(colored), [Run(text: "Text", color: .purple, strike: false)])
    }

    func testOSC8AroundRealContentDoesNotEatText() {
        let st = "\u{1B}\\"
        let ansi = "before \u{1B}]8;;x\(st)mid\u{1B}]8;;\(st) after"
        XCTAssertEqual(plainText(ansi), "before mid after")
    }
}
