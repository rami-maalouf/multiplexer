import CryptoKit
import Foundation
import LinkPresentation
import UIKit

/// Link previews (R11): a card with a page's title and picture for a link in a message. The phone
/// fetches the page itself with Apple's LinkPresentation, never the Matrix server's preview, so a
/// link in an end-to-end encrypted chat does not reach the server. Each preview is kept in the
/// cache with the downloaded pictures (`matrix-media`), so a chat opened again shows it at once,
/// and Sign Out deletes it with them.
extension Matrix {
    /// `known`: the links of the open chat's loaded messages, whose kept previews are answered.
    /// `fetch`: those of the messages on screen, fetched when no preview is kept yet. Answers the
    /// kept previews: `state` "ready" (a title or a picture) or "none" (the page gave neither, or
    /// could not be read).
    @MainActor func linkPreviews(_ request: [String: Any]) -> [String: Any] {
        let known = (request["known"] as? [String]) ?? [], fetch = Set((request["fetch"] as? [String]) ?? [])
        var items: [[String: Any]] = []
        for url in Set(known) {
            guard let page = URL(string: url), ["http", "https"].contains(page.scheme?.lowercased() ?? "") else { continue }
            let name = Self.linkPreviewName(url)
            if let kept = Self.keptLinkPreview(name, in: media) {
                items.append(kept)
            } else if fetch.contains(url) {
                // a fetch at most once at a time per link; `cached` tells the view's sources (topic
                // "links") when it ends, and leaves a link that failed alone until the next launch.
                _ = cached(name, topic: "links") { [media] in
                    try await Self.fetchLinkPreview(page, url: url, name: name, directory: media)
                }
            }
        }
        return ["items": items]
    }

    /// The kept preview, or nil when there is none: none yet, or a page that gave nothing a day
    /// ago, which is then fetched again. Plain file reads, so a synchronous call can ask too.
    nonisolated static func keptLinkPreview(_ name: String, in media: URL) -> [String: Any]? {
        let file = media.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: file),
              let kept = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        let at = (kept["at"] as? NSNumber)?.doubleValue ?? 0
        if kept["state"] as? String == "none", Date().timeIntervalSince1970 - at > 24 * 60 * 60 {
            try? FileManager.default.removeItem(at: file)
            return nil
        }
        let image = kept["image"] as? String ?? ""
        return ["url": kept["url"] as? String ?? "", "title": kept["title"] as? String ?? "",
                "image": image.isEmpty ? "" : "app:/cache/matrix-media/\(image)",
                "width": kept["width"] as? Int ?? 0, "height": kept["height"] as? Int ?? 0,
                "state": kept["state"] as? String ?? "none"]
    }

    /// The preview's file name: the same for the same link.
    nonisolated static func linkPreviewName(_ url: String) -> String {
        "link-" + SHA256.hash(data: Data(url.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined() + ".json"
    }

    /// Fetches the page's title and picture, keeps the picture as a JPEG of at most 900 points a
    /// side, and writes the preview (`state` "none" when the page gave neither, or failed).
    @MainActor static func fetchLinkPreview(_ page: URL, url: String, name: String, directory: URL) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var title = "", imageName = "", width = 0, height = 0
        let provider = LPMetadataProvider()
        provider.timeout = 12
        var metadata: LPLinkMetadata?
        do { metadata = try await provider.startFetchingMetadata(for: page) } catch { print("matrix: link preview failed for \(page.host ?? ""): \(error)") }
        if let metadata {
            title = (metadata.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let image = await loadImage(metadata.imageProvider), let jpeg = smaller(image) {
                imageName = name.replacingOccurrences(of: ".json", with: ".jpg")
                try jpeg.data.write(to: directory.appendingPathComponent(imageName), options: .atomic)
                (width, height) = (jpeg.width, jpeg.height)
            }
        }
        let kept: [String: Any] = ["url": url, "title": title, "image": imageName, "width": width, "height": height,
                                   "state": title.isEmpty && imageName.isEmpty ? "none" : "ready",
                                   "at": Date().timeIntervalSince1970]
        let data = try JSONSerialization.data(withJSONObject: kept)
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
        print("matrix: link preview \(kept["state"] ?? "") for \(page.host ?? "")")
    }

    private static func loadImage(_ provider: NSItemProvider?) async -> UIImage? {
        guard let provider, provider.canLoadObject(ofClass: UIImage.self) else { return nil }
        return await withCheckedContinuation { done in
            provider.loadObject(ofClass: UIImage.self) { object, _ in done.resume(returning: object as? UIImage) }
        }
    }

    private static func smaller(_ image: UIImage) -> (data: Data, width: Int, height: Int)? {
        let side = max(image.size.width, image.size.height)
        guard side > 0 else { return nil }
        let scale = min(1, 900 / side)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let drawn = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = drawn.jpegData(compressionQuality: 0.8) else { return nil }
        return (data, Int(size.width), Int(size.height))
    }
}
