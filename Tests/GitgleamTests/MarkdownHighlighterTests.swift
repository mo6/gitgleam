import XCTest
@testable import Gitgleam

final class MarkdownHighlighterTests: XCTestCase {
    func testNoDiffLeavesContentUnchanged() {
        let content = "# Title\n\nBody\n"
        XCTAssertEqual(MarkdownHighlighter.mark(content, unifiedDiff: ""), content)
        XCTAssertEqual(
            MarkdownHighlighter.mark(content, unifiedDiff: "No textual differences."),
            content
        )
    }

    func testPartialChangeMarksBlockAsChanged() {
        let content = """
        # Title

        Para line one
        Para line two
        """
        // Only line 4 ("Para line two") changed.
        let diff = """
        @@ -1,4 +1,4 @@
         # Title
        \u{20}
         Para line one
        -Para line old
        +Para line two
        """
        let out = MarkdownHighlighter.mark(content, unifiedDiff: diff)
        XCTAssertTrue(out.contains("""
        <!-- viewmd:mark start kind=changed -->
        Para line one
        Para line two
        <!-- viewmd:mark end -->
        """))
        // The unchanged heading block is not wrapped.
        XCTAssertFalse(out.contains("start kind=changed -->\n# Title"))
        XCTAssertFalse(out.contains("start kind=added"))
    }

    func testWhollyNewBlocksAreAdded() {
        let content = """
        # New

        Body
        """
        // A brand-new file: every line is an addition (diff vs /dev/null).
        let diff = """
        @@ -0,0 +1,3 @@
        +# New
        +
        +Body
        """
        let out = MarkdownHighlighter.mark(content, unifiedDiff: diff)
        // Two separate added regions (heading and body), each wrapped.
        XCTAssertTrue(out.contains("<!-- viewmd:mark start kind=added -->\n# New\n<!-- viewmd:mark end -->"))
        XCTAssertTrue(out.contains("<!-- viewmd:mark start kind=added -->\nBody\n<!-- viewmd:mark end -->"))
    }

    func testFencedBlockIsMarkedAsOneRegionEvenWithInnerBlankLine() {
        let content = """
        Text before

        ```mermaid
        graph LR

          A --> B
        ```

        Text after
        """
        // Only the "A --> B" line (line 6) changed.
        let diff = """
        @@ -1,9 +1,9 @@
         Text before
        \u{20}
         ```mermaid
         graph LR
        \u{20}
        -  A --> C
        +  A --> B
         ```
        \u{20}
         Text after
        """
        let out = MarkdownHighlighter.mark(content, unifiedDiff: diff)
        // The whole fence (including its internal blank line) is one region.
        XCTAssertTrue(out.contains("""
        <!-- viewmd:mark start kind=changed -->
        ```mermaid
        graph LR

          A --> B
        ```
        <!-- viewmd:mark end -->
        """))
        // Surrounding paragraphs are untouched.
        XCTAssertFalse(out.contains("start kind=changed -->\nText before"))
        XCTAssertFalse(out.contains("start kind=changed -->\nText after"))
    }

    func testOnlyTheChangedListItemIsMarked() {
        let content = """
        - Item one
        - Item two
        - Item three
        """
        // Only "Item two" (line 2) changed. Its whole (one-line) block is
        // replaced, which the existing "every line is new" heuristic reports
        // as `added` rather than `changed` — see `testPartialChangeMarksBlockAsChanged`
        // for the multi-line case where that distinction actually applies.
        let diff = """
        @@ -1,3 +1,3 @@
         - Item one
        -- Item two old
        +- Item two
         - Item three
        """
        let out = MarkdownHighlighter.mark(content, unifiedDiff: diff)
        XCTAssertTrue(out.contains("""
        <!-- viewmd:mark start kind=added -->
        - Item two
        <!-- viewmd:mark end -->
        """))
        // The unrelated sibling items are not wrapped.
        XCTAssertFalse(out.contains("- Item one\n<!-- viewmd:mark end -->"))
        XCTAssertFalse(out.contains("- Item three\n<!-- viewmd:mark end -->"))
    }

    func testListItemContinuationLineStaysWithItsItem() {
        let content = """
        - Item one
          continues here
        - Item two
        """
        // Both lines of "Item one" changed; "Item two" is untouched.
        let diff = """
        @@ -1,3 +1,3 @@
        -- Item one old
        -  continues old
        +- Item one
        +  continues here
         - Item two
        """
        let out = MarkdownHighlighter.mark(content, unifiedDiff: diff)
        // Both of the block's lines were replaced, so — same heuristic as
        // above — it's reported as `added`.
        XCTAssertTrue(out.contains("""
        <!-- viewmd:mark start kind=added -->
        - Item one
          continues here
        <!-- viewmd:mark end -->
        """))
        XCTAssertFalse(out.contains("- Item two\n<!-- viewmd:mark end -->"))
    }

    func testListItemMarkersInsideFenceDoNotSplitTheBlock() {
        let content = """
        ```
        - not a list
        - still code
        ```
        """
        let diff = """
        @@ -1,4 +1,4 @@
         ```
        -- not code
        +- not a list
         - still code
         ```
        """
        let out = MarkdownHighlighter.mark(content, unifiedDiff: diff)
        XCTAssertTrue(out.contains("""
        <!-- viewmd:mark start kind=changed -->
        ```
        - not a list
        - still code
        ```
        <!-- viewmd:mark end -->
        """))
    }

    func testFrontMatterIsNeverMarkedEvenWhenChanged() {
        let content = """
        ---
        title: Topics
        updated: 2026-08-23
        ---
        # Topics
        - Item
        """
        // Every line changed, including the front matter and the heading.
        let diff = """
        @@ -0,0 +1,6 @@
        +---
        +title: Topics
        +updated: 2026-08-23
        +---
        +# Topics
        +- Item
        """
        let out = MarkdownHighlighter.mark(content, unifiedDiff: diff)
        // No sentinel ever appears before the closing "---": the front matter
        // is untouched, including its literal first-line "---".
        XCTAssertTrue(out.hasPrefix("---\n"))
        // The heading right after front matter (no blank line) is still its
        // own, separately markable block.
        XCTAssertTrue(out.contains("""
        <!-- viewmd:mark start kind=added -->
        # Topics
        <!-- viewmd:mark end -->
        """))
    }

    func testFrontMatterWithoutClosingDelimiterIsNotTreatedAsFrontMatter() {
        // A lone leading "---" with no closing delimiter isn't front matter
        // (e.g. it's a thematic break) — nothing should be skipped, and the
        // changed line is still marked normally.
        let content = "---\nBody\n"
        let diff = "@@ -0,0 +1,2 @@\n+---\n+Body\n"
        let out = MarkdownHighlighter.mark(content, unifiedDiff: diff)
        XCTAssertTrue(out.contains("<!-- viewmd:mark start kind=added -->\n---\nBody\n<!-- viewmd:mark end -->"))
    }

    func testSentinelsAreValidHTMLCommentsAndBalanced() {
        let content = "a\n\nb\n"
        let diff = "@@ -1,3 +1,3 @@\n-a-old\n+a\n \n b\n"
        let out = MarkdownHighlighter.mark(content, unifiedDiff: diff)
        let starts = out.components(separatedBy: MarkdownHighlighter.startPrefix).count - 1
        let ends = out.components(separatedBy: MarkdownHighlighter.endMarker).count - 1
        XCTAssertEqual(starts, ends, "every start marker must have a matching end")
        XCTAssertGreaterThan(starts, 0)
    }
}
