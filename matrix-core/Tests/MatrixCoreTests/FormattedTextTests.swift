import XCTest
@testable import MatrixCore

/// a bridged message's html body becomes the bubble's plain text, without the plain body's marks.
final class FormattedTextTests: XCTestCase {
    func testABridgedLinkAndBoldReadAsTheirText() {
        let html = #"<strong>Look</strong> at <a href="https://instagram.com/p/x">https://instagram.com/p/x</a>"#
        XCTAssertEqual(FormattedText.plain(html: html), "Look at https://instagram.com/p/x")
    }
    func testALinkWithOtherTextKeepsItsAddress() {
        XCTAssertEqual(FormattedText.plain(html: #"<a href="https://a.example/b">the post</a>"#), "the post (https://a.example/b)")
    }
    func testAMentionIsItsNameAndTheReplyFallbackGoes() {
        let html = #"<mx-reply><blockquote>old</blockquote></mx-reply><a href="https://matrix.to/#/@a:b.c">Ann</a> hi"#
        XCTAssertEqual(FormattedText.plain(html: html), "Ann hi")
    }
    func testLinesListsAndEntities() {
        XCTAssertEqual(FormattedText.plain(html: "a<br>b<ul><li>c</li><li>d &amp; e</li></ul>&#1605;&#x631;"), "a\nb• c\n• d & e\nمر")
    }
}
