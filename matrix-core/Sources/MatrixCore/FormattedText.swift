import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// a text message's words as the chat shows them. a bridge (Instagram's, WhatsApp's) writes its
/// formatting into the html body and leaves markdown-like marks in the plain one (`**bold**`,
/// `[link](link)`), so the html body, when there is one, is turned into plain text: its line breaks,
/// paragraphs and list items kept, a link written as its text (and its address when that differs),
/// a mention as its name, and the reply fallback dropped. the bubble finds the addresses itself.
enum FormattedText {
    static func plain(_ body: String, _ formatted: FormattedBody?) -> String {
        guard let formatted, case .html = formatted.format else { return body }
        let text = plain(html: formatted.body)
        return text.isEmpty ? body : text
    }

    /// a photo's, video's, file's or audio's caption as the chat shows it: from its html caption when
    /// it has one, as a text's body; "" when it has none.
    static func caption(_ caption: String?, _ formatted: FormattedBody?) -> String {
        guard let formatted, case .html = formatted.format else { return caption ?? "" }
        return self.caption(caption, html: formatted.body)
    }

    /// a caption from its plain text and its html, when it has one.
    static func caption(_ caption: String?, html: String?) -> String {
        guard let caption else { return "" }
        guard let html else { return caption }
        let text = plain(html: html)
        return text.isEmpty ? caption : text
    }

    static func plain(html: String) -> String {
        var s = html
        // the reply fallback quotes the answered message; the bubble shows its own quote.
        s = replace(s, #"(?is)<mx-reply>.*?</mx-reply>"#) { _ in "" }
        // a code block keeps its own lines and spaces: set aside here, put back at the end.
        var code: [String] = []
        s = replace(s, #"(?is)<pre[^>]*>(.*?)</pre>"#) { m in
            code.append(decode(strip(m[1])))
            return "<p>\u{E000}\(code.count - 1)\u{E001}</p>"
        }
        // as html is shown, a line break in its source is a space (Instagram's bridge writes a caption's
        // own line breaks into its bold title, which its plain body leaves out).
        s = replace(s, #"[ \t\r\n]+"#) { _ in " " }
        s = replace(s, #"(?is)<a\s[^>]*href\s*=\s*["']([^"']*)["'][^>]*>(.*?)</a>"#) { m in
            let href = decode(m[1]), text = decode(strip(m[2]))
            if href.hasPrefix("https://matrix.to/") || text.isEmpty || text == href || "mailto:" + text == href
                || href.hasSuffix(text) && text.contains(".")
                // an address shown without its query, as Instagram's bridge writes a post's link.
                || href.hasPrefix(text) && text.contains("://") { return text.isEmpty ? href : text }
            return "\(text) (\(href))"
        }
        s = replace(s, #"(?i)<br\s*/?>"#) { _ in "\n" }
        s = replace(s, #"(?i)<li[^>]*>"#) { _ in "• " }
        // a paragraph or a block starts and ends its own line.
        s = replace(s, #"(?i)<(p|div|blockquote|h[1-6]|tr|ul|ol)(\s[^>]*)?>"#) { _ in "\n" }
        s = replace(s, #"(?i)</(p|div|li|blockquote|h[1-6]|tr)>"#) { _ in "\n" }
        s = decode(strip(s))
        // a space at a line's ends goes, and no more than one empty line stays between two.
        s = replace(s, #" *\n *"#) { _ in "\n" }
        s = replace(s, #"\n{3,}"#) { _ in "\n\n" }
        s = replace(s, #"\x{E000}([0-9]+)\x{E001}"#) { m in Int(m[1]).flatMap { code.indices.contains($0) ? code[$0] : nil } ?? "" }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func strip(_ s: String) -> String { replace(s, #"<[^>]+>"#) { _ in "" } }

    private static func decode(_ s: String) -> String {
        guard s.contains("&") else { return s }
        let named = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}"]
        return replace(s, #"&(#[0-9]+|#[xX][0-9a-fA-F]+|[a-zA-Z]+);"#) { m in
            let e = m[1]
            if e.hasPrefix("#x") || e.hasPrefix("#X") {
                return UInt32(e.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map { String(Character($0)) } ?? m[0]
            }
            if e.hasPrefix("#") { return UInt32(e.dropFirst()).flatMap(Unicode.Scalar.init).map { String(Character($0)) } ?? m[0] }
            return named[e.lowercased()] ?? m[0]
        }
    }

    /// each match of `pattern` replaced by what `with` makes of its groups (0 the whole match).
    private static func replace(_ s: String, _ pattern: String, with: ([String]) -> String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return s }
        let ns = s as NSString
        var out = "", last = 0
        for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            let groups = (0..<m.numberOfRanges).map { i -> String in
                let r = m.range(at: i); return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
            out += with(groups)
            last = m.range.location + m.range.length
        }
        return out + ns.substring(from: last)
    }
}

extension FormattedText {
    /// a message's own words as every screen shows them: a text's, notice's or emote's, and a photo's,
    /// video's, file's or audio's caption ("" without one), each from its html when it has one; nil for
    /// any other kind, which keeps its body.
    static func words(_ type: MessageType) -> String? {
        switch type {
        case .text(let c): return plain(c.body, c.formatted)
        case .notice(let c): return plain(c.body, c.formatted)
        case .emote(let c): return plain(c.body, c.formatted)
        case .image(let c): return caption(c.caption, c.formattedCaption)
        case .video(let c): return caption(c.caption, c.formattedCaption)
        case .file(let c): return caption(c.caption, c.formattedCaption)
        case .audio(let c): return caption(c.caption, c.formattedCaption)
        default: return nil
        }
    }
}
