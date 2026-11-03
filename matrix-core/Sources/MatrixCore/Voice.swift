import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// Voice messages (B16, B17): what a received one shows, its sound downloaded to play, and one
/// recorded here sent as a voice message (`VoiceNote` makes it ready).

/// An audio message's sound: a voice message recorded in a chat, or an audio file someone shared
/// (`MatrixAccount.audioFile` downloads it).
public struct MessageAudio: Equatable, Sendable {
    /// A voice message (MSC3245), which WhatsApp calls a voice note; else a shared audio file.
    public var isVoice: Bool
    /// In milliseconds; 0 when the sender did not say.
    public var duration: Int
    /// How loud each part of it is, from 0 to 1, the loudest part 1 (MSC1767's waveform: Element
    /// sends 0 to 1024, the WhatsApp bridge 0 to 100); empty when the sender sent none.
    public var waveform: [Double]
    /// The file name `audioFile` gives it, with the extension its type plays under.
    public var fileName: String
    /// In bytes; 0 when the sender did not say.
    public var size: Int
    public var mimetype: String
}

extension MessageAudio {
    init(_ content: AudioMessageContent) {
        let key = mediaKey(content.source.url())
        let mimetype = content.info?.mimetype ?? ""
        let ext: String
        switch mimetype.split(separator: ";").first.map({ $0.trimmingCharacters(in: .whitespaces) }) ?? "" {
        case "audio/ogg", "audio/opus": ext = "ogg"
        case "audio/mp4", "audio/aac", "audio/x-m4a", "audio/m4a": ext = "m4a"
        case "audio/mpeg", "audio/mp3": ext = "mp3"
        case "audio/wav", "audio/x-wav", "audio/wave": ext = "wav"
        case "audio/webm": ext = "webm"
        case "audio/amr": ext = "amr"
        default:
            let named = (content.filename as NSString).pathExtension.lowercased()
            ext = named.isEmpty || named.count > 5 ? "ogg" : named
        }
        let levels = content.audio?.waveform.map(Double.init) ?? []
        let loudest = levels.max() ?? 0
        let seconds = content.info?.duration ?? content.audio?.duration ?? 0
        self.init(isVoice: content.voice != nil, duration: Int((seconds * 1000).rounded()),
                  waveform: loudest > 0 ? levels.map { ($0 / loudest * 1000).rounded() / 1000 } : levels.map { _ in 0 },
                  fileName: "\(key).\(ext)", size: Int(content.info?.size ?? 0), mimetype: mimetype)
    }
}

extension MatrixAccount {
    /// Puts a voice message in the room's send queue, as a voice note other clients and WhatsApp
    /// show: the Ogg Opus file `VoiceNote.prepare` made, its length and its waveform. It returns
    /// once the queue holds it, with the id of its message in the chat (nil if it did not show
    /// within a second); the chat shows it at once as `sending`, as a photo. With `replyTo` (a
    /// message's id, or the event id a draft keeps) it answers that message.
    @discardableResult
    public func sendVoice(roomId: String, note: VoiceNote, replyTo: String? = nil, timeout: TimeInterval = 30) async throws -> String? {
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        let params = UploadParameters(source: .file(filename: note.file.path), caption: nil, formattedCaption: nil, mentions: nil,
                                      inReplyTo: live.items.replyEventId(replyTo))
        // the bridge needs audio/ogg, and the voice mark, to send a voice note. The sdk cuts the seconds
        // down to whole milliseconds (3.15 s, a binary 3.1499..., went out as 3149): half a
        // millisecond more makes it the note's own.
        let info = AudioInfo(duration: (Double(note.duration) + 0.5) / 1000, size: UInt64(note.size), mimetype: "audio/ogg")
        let before = Set(live.items.messages().map(\.id))
        try await live.timeline.sendAttachment(params: params, attachment: .voice(audioInfo: info, waveform: note.waveform.map(Float.init))).join()
        // its local echo reaches the timeline on the sdk's own task, a moment after.
        let start = Date()
        repeat {
            if let echo = live.items.messages().last(where: { $0.isOwn && $0.audio != nil && !before.contains($0.id) }) { return echo.id }
            try await Task.sleep(nanoseconds: 20_000_000)
        } while Date().timeIntervalSince(start) < 1
        return nil
    }

    /// An audio message's sound as a file in `directory`, to play. Downloaded once; later calls
    /// return the same file. Throws `noAudio` for a message that is not an audio message.
    public func audioFile(roomId: String, messageId: String, directory: URL, timeout: TimeInterval = 30) async throws -> URL {
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        guard let event = live.items.event(of: messageId), case .msgLike(let like) = event.content,
              case .message(let message) = like.kind, case .audio(let content) = message.msgType else {
            throw MatrixCoreError.noAudio(messageId)
        }
        let file = directory.appendingPathComponent(MessageAudio(content).fileName)
        if FileManager.default.fileExists(atPath: file.path) { return file }
        let data = try await client.getMediaContent(mediaSource: content.source)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
        return file
    }
}
