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

    static func plain(html: String) -> String {
        var s = html
        // the reply fallback quotes the answered message; the bubble shows its own quote.
        s = replace(s, #"(?is)<mx-reply>.*?</mx-reply>"#) { _ in "" }
        s = replace(s, #"(?is)<a\s[^>]*href\s*=\s*["']([^"']*)["'][^>]*>(.*?)</a>"#) { m in
            let href = decode(m[1]), text = decode(strip(m[2]))
            if href.hasPrefix("https://matrix.to/") || text.isEmpty || text == href || "mailto:" + text == href
                || href.hasSuffix(text) && text.contains(".") { return text.isEmpty ? href : text }
            return "\(text) (\(href))"
        }
        s = replace(s, #"(?i)<br\s*/?>"#) { _ in "\n" }
        s = replace(s, #"(?i)<li[^>]*>"#) { _ in "• " }
        s = replace(s, #"(?i)</(p|div|li|blockquote|h[1-6]|pre|tr)>"#) { _ in "\n" }
        s = decode(strip(s))
        s = replace(s, #"\n{3,}"#) { _ in "\n\n" }
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
