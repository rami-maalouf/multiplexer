import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// Photos and files: sending them through the room's send queue, and downloading a file
/// message's file to open it.
extension MatrixAccount {
    /// Puts a photo or a file in the room's send queue and returns once the queue holds it,
    /// with the id of its message in the chat (nil if it did not show within a second).
    /// The chat shows it at once as `sending`, with its `uploadProgress`, then `sent`, or
    /// `failed` (then `retry` and `discard` work as for text). `caption` shows with it; with
    /// `replyTo`, a message's id (or the event id a draft keeps), it answers that message.
    @discardableResult
    public func sendAttachment(roomId: String, attachment: Attachment, caption: String? = nil, replyTo: String? = nil,
                               timeout: TimeInterval = 30) async throws -> String? {
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        let inReplyTo = live.items.replyEventId(replyTo)
        // the sdk names the media after the file's last path component, so a file whose name is
        // not the one to show goes as a link of that name (no copy), until the queue holds it.
        var source = attachment.file
        let named = safeFileName(attachment.name)
        if source.lastPathComponent != named {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("matrix-upload-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            source = folder.appendingPathComponent(named)
            do { try FileManager.default.linkItem(at: attachment.file, to: source) } catch { try FileManager.default.copyItem(at: attachment.file, to: source) }
        }
        defer { if source != attachment.file { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) } }
        let params = UploadParameters(source: .file(filename: source.path), caption: caption?.isEmpty == false ? caption : nil,
                                      formattedCaption: nil, mentions: nil, inReplyTo: inReplyTo)
        let kind: AttachmentKind
        switch attachment.kind {
        case .photo(let width, let height):
            let small = attachment.thumbnail
            kind = .image(imageInfo: ImageInfo(height: UInt64(height), width: UInt64(width), mimetype: attachment.mimetype,
                                               size: UInt64(attachment.size),
                                               thumbnailInfo: small.map { ThumbnailInfo(height: UInt64($0.height), width: UInt64($0.width),
                                                                                         mimetype: $0.mimetype, size: UInt64($0.size)) },
                                               thumbnailSource: nil, blurhash: nil,
                                               // an animated GIF says so (MSC4230), so other apps play it.
                                               isAnimated: attachment.mimetype == "image/gif" ? true : nil),
                          thumbnailSource: small.map { .file(filename: $0.file.path) })
        case .file:
            kind = .file(fileInfo: FileInfo(mimetype: attachment.mimetype, size: UInt64(attachment.size), thumbnailInfo: nil, thumbnailSource: nil))
        }
        let before = Set(live.items.messages().map(\.id))
        try await live.timeline.sendAttachment(params: params, attachment: kind).join()
        // the caption was the chat's draft: a relaunch does not offer it again.
        try? await room(roomId, timeout: timeout).clearComposerDraft(threadRoot: nil)
        // its local echo reaches the timeline on the sdk's own task, a moment after.
        let start = Date()
        repeat {
            if let echo = live.items.messages().last(where: { $0.isOwn && $0.sendState != .sent && !before.contains($0.id) }) { return echo.id }
            try await Task.sleep(nanoseconds: 20_000_000)
        } while Date().timeIntervalSince(start) < 1
        return nil
    }

    /// The largest upload the server takes, in bytes.
    public func maxUploadSize() async throws -> Int {
        Int(clamping: try await client.getMaxMediaUploadSize())
    }

    /// A file message's file in `directory`, under the name its sender gave it, to open or
    /// share. Downloaded once; later calls return the same file.
    public func fileContent(roomId: String, messageId: String, directory: URL, timeout: TimeInterval = 30) async throws -> URL {
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        guard let event = live.items.event(of: messageId), case .msgLike(let like) = event.content,
              case .message(let message) = like.kind, case .file(let content) = message.msgType else {
            throw MatrixCoreError.noFile(messageId)
        }
        // one folder for each file, so two files of the same name never meet.
        let file = directory.appendingPathComponent(mediaKey(content.source.url()), isDirectory: true)
            .appendingPathComponent(safeFileName(content.filename))
        if FileManager.default.fileExists(atPath: file.path) { return file }
        let data = try await client.getMediaContent(mediaSource: content.source)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
        return file
    }
}

extension MessageFile {
    init(_ content: FileMessageContent) {
        self.init(name: content.filename, size: Int(content.info?.size ?? 0), mimetype: content.info?.mimetype ?? "")
    }
}

/// A photo's or file's upload, as a fraction of its bytes (its thumbnail's too).
func uploadedFraction(_ progress: MediaUploadProgress) -> Double {
    progress.progress.total == 0 ? 0 : min(1, Double(progress.progress.current) / Double(progress.progress.total))
}

/// A sender's file name as one safe path component: no folders, no hidden file.
private func safeFileName(_ name: String) -> String {
    let last = name.split(separator: "/").last.map(String.init) ?? ""
    let trimmed = last.trimmingCharacters(in: CharacterSet(charactersIn: ". ").union(.whitespacesAndNewlines))
    return trimmed.isEmpty ? "File" : trimmed
}
