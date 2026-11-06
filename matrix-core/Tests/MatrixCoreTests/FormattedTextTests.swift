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
        XCTAssertEqual(FormattedText.plain(html: "a<br>b<ul><li>c</li><li>d &amp; e</li></ul>&#1605;&#x631;"), "a\nb\n• c\n• d & e\nمر")
    }

    // the shape of an Instagram post shared in a chat, as its bridge writes it: an image whose caption
    // is the post's bold title, then a paragraph with the post's link, shown without its query. The
    // plain caption is `**title**\n[address](address?query)`.
    func testASharedPostsCaptionIsItsTitleThenItsLinkOnce() {
        let html = #"<strong>someone . . . A title …</strong><p><a href="https://www.instagram.com/p/AbC/?is_sponsored=false&amp;x=1">https://www.instagram.com/p/AbC/</a></p>"#
        XCTAssertEqual(FormattedText.caption("**someone . . . A title …**\n[https://www.instagram.com/p/AbC/](https://www.instagram.com/p/AbC/?is_sponsored=false&x=1)",
                                             html: html),
                       "someone . . . A title …\nhttps://www.instagram.com/p/AbC/")
    }
    func testASharedPostWithNoTitleIsItsLink() {
        let html = #"<p><a href="https://www.instagram.com/reel/XyZ/?a=b">https://www.instagram.com/reel/XyZ/</a></p>"#
        XCTAssertEqual(FormattedText.plain(html: html), "https://www.instagram.com/reel/XyZ/")
    }
    // the html's own line breaks are spaces, as html shows them.
    func testLineBreaksInTheHtmlSourceAreSpaces() {
        XCTAssertEqual(FormattedText.plain(html: "<strong>a .\n.\n.\n#tag</strong>"), "a . . . #tag")
    }
    func testACodeBlockKeepsItsLinesAndSpaces() {
        XCTAssertEqual(FormattedText.plain(html: "see<pre><code>if a {\n    b()\n}</code></pre>done"), "see\nif a {\n    b()\n}\ndone")
    }
    // a caption with no html, and no caption at all.
    func testACaptionWithoutHtmlIsAsWrittenAndNoCaptionIsEmpty() {
        XCTAssertEqual(FormattedText.caption("a photo", html: nil), "a photo")
        XCTAssertEqual(FormattedText.caption(nil, html: nil), "")
    }
}
