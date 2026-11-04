import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// A message's long-press actions: edit and delete your own, forward a message to another chat,
/// the original of a photo or file to share, and the emojis this account reacts with most.
extension MatrixAccount {
    /// Changes the text of your own text message (`Message.isEditable`). Everyone in the chat sees
    /// the new text, marked edited; a bridge passes the edit on where its network allows one.
    public func edit(roomId: String, messageId: String, text: String, timeout: TimeInterval = 30) async throws {
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        guard let event = live.items.event(of: messageId), case .msgLike(let like) = event.content,
              case .message(let message) = like.kind, Message.isEditable(event, message) else {
            throw MatrixCoreError.notEditable(messageId)
        }
        try await live.timeline.edit(eventOrTransactionId: event.eventOrTransactionId,
                                     newContent: .roomMessage(content: messageEventContentFromMarkdown(md: text)))
    }

    /// Deletes a message for everyone in the chat (a redaction): it then shows as deleted
    /// (`Message.isDeleted`), here, for the others and in the list's preview. A message still in
    /// the send queue is not sent.
    public func delete(roomId: String, messageId: String, timeout: TimeInterval = 30) async throws {
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        guard let itemId = live.items.eventOrTransactionId(of: messageId) else { return }
        try await live.timeline.redactEvent(eventOrTransactionId: itemId, reason: nil)
    }

    /// Sends a copy of a message to another chat, through that chat's send queue: its text, or its
    /// photo or file with its caption, from the same media on the server (no new upload). The copy
    /// answers no message, and Matrix has no mark for a forwarded message.
    public func forward(roomId: String, messageId: String, to targetRoomId: String, timeout: TimeInterval = 30) async throws {
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        guard let event = live.items.event(of: messageId), case .msgLike(let like) = event.content,
              case .message(let message) = like.kind else {
            throw MatrixCoreError.notForwardable(messageId)
        }
        let content = try contentWithoutRelationFromMessage(message: message)
        let target = try await liveTimeline(targetRoomId, limit: 20, timeout: timeout)
        _ = try await target.timeline.send(msg: content)
    }

    /// A photo's, a video's or a file's original in `directory`, under the name its sender gave it,
    /// to share. Downloaded once; later calls return the same file.
    public func mediaFile(roomId: String, messageId: String, directory: URL, timeout: TimeInterval = 30) async throws -> URL {
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        guard let event = live.items.event(of: messageId), case .msgLike(let like) = event.content,
              case .message(let message) = like.kind else { throw MatrixCoreError.noFile(messageId) }
        switch message.msgType {
        case .image(let content):
            let file = directory.appendingPathComponent(mediaKey(content.source.url()), isDirectory: true)
                .appendingPathComponent(shareName(content.filename, fallback: "Photo.jpg"))
            if FileManager.default.fileExists(atPath: file.path) { return file }
            let data = try await client.getMediaContent(mediaSource: content.source)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
            return file
        case .file:
            return try await fileContent(roomId: roomId, messageId: messageId, directory: directory, timeout: timeout)
        case .video(let content):
            // a folder of its own, as a file's; the video downloads under the cache's name, and the
            // share sheet gets it under its sender's (a link to the same bytes).
            let folder = directory.appendingPathComponent(mediaKey(content.source.url()), isDirectory: true)
            let named = folder.appendingPathComponent(shareName(content.filename, fallback: "Video.mp4"))
            if FileManager.default.fileExists(atPath: named.path) { return named }
            let downloaded = try await videoFile(roomId: roomId, messageId: messageId, directory: folder, timeout: timeout)
            if downloaded.lastPathComponent == named.lastPathComponent { return downloaded }
            do { try FileManager.default.linkItem(at: downloaded, to: named) } catch { try FileManager.default.copyItem(at: downloaded, to: named) }
            return named
        case .audio(let content):
            let file = directory.appendingPathComponent(mediaKey(content.source.url()), isDirectory: true)
                .appendingPathComponent(shareName(content.filename, fallback: "Voice message.ogg"))
            if FileManager.default.fileExists(atPath: file.path) { return file }
            let data = try await client.getMediaContent(mediaSource: content.source)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
            return file
        default:
            throw MatrixCoreError.noFile(messageId)
        }
    }

    /// The emojis this account reacts with most, the most used first (the latest among equals), at
    /// most `limit`. They are the account's (`io.element.recent_emoji`, as Element keeps them), so
    /// its other devices and Element share them.
    public func frequentEmojis(limit: Int = 18) async throws -> [String] {
        await currentEmojiUses().frequent(limit: limit)
    }

    /// Forgets the emojis this account reacted with, on every device.
    public func resetFrequentEmojis() async throws {
        try await changeEmojiUses { $0 = EmojiUses() }
    }

    static let recentEmojiType = "io.element.recent_emoji"

    /// Counts a reaction this account adds among its frequent emojis. The sdk's own
    /// `addRecentEmoji` counts from its store, which the sync fills up to half a minute later, so
    /// a second reaction before that would drop the first.
    func countReaction(_ key: String) async {
        try? await changeEmojiUses { $0.add(key) }
    }

    /// The emojis this device last wrote until the store has them, else the store's.
    private func currentEmojiUses() async -> EmojiUses {
        emojiUses.uses(stored: EmojiUses(json: (try? await client.accountData(eventType: Self.recentEmojiType)) ?? nil))
    }

    /// Changes the emoji counts one change at a time, from the newest this device knows.
    private func changeEmojiUses(_ change: @escaping @Sendable (inout EmojiUses) -> Void) async throws {
        try await emojiUses.serially {
            // the store's counts, else the server's: a new device must not start from none.
            var uses = self.emojiUses.uses(stored: EmojiUses(json: try await self.accountDataForChange(Self.recentEmojiType)))
            change(&uses)
            self.emojiUses.wrote(uses)
            do {
                try await self.client.setAccountData(eventType: Self.recentEmojiType, content: uses.json())
            } catch {
                self.emojiUses.wrote(nil)
                throw error
            }
        }
    }
}

extension RoomSummary {
    /// A deleted message newer than the sdk's latest event, which leaves deleted messages out: the
    /// preview says so, as the chat does. Only an open chat's timeline knows it. The time stays the
    /// latest event's, as the list's order does.
    mutating func fillDeleted(_ messages: [Message]) {
        guard let newest = messages.last, newest.isDeleted, newest.timestamp >= lastTimestamp else { return }
        lastMessage = "Message deleted"
        lastSenderName = newest.senderName
        lastIsOwn = newest.isOwn
    }
}

/// The emojis an account reacted with, as `io.element.recent_emoji` keeps them for Element:
/// `{"recent_emoji": [["👍", 3], ...]}`, the latest first, each with its count.
struct EmojiUses: Equatable, Sendable {
    /// The most kept, as Element keeps them.
    static let limit = 100

    var uses: [Use] = []

    struct Use: Equatable, Sendable {
        var emoji: String
        var count: Int
    }

    init() {}

    /// From the event's content; empty for none.
    init(json: String?) {
        guard let data = json?.data(using: .utf8),
              let content = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let list = content["recent_emoji"] as? [Any] else { return }
        uses = list.compactMap { entry in
            guard let pair = entry as? [Any], pair.count == 2, let emoji = pair[0] as? String,
                  let count = (pair[1] as? NSNumber)?.intValue else { return nil }
            return Use(emoji: emoji, count: count)
        }
    }

    func json() -> String {
        let content = ["recent_emoji": uses.map { [$0.emoji, $0.count] as [Any] }]
        let data = (try? JSONSerialization.data(withJSONObject: content)) ?? Data(#"{"recent_emoji":[]}"#.utf8)
        return String(decoding: data, as: UTF8.self)
    }

    /// One more use of `emoji`: it moves to the front.
    mutating func add(_ emoji: String) {
        let count = (uses.first { $0.emoji == emoji }?.count ?? 0) + 1
        uses.removeAll { $0.emoji == emoji }
        uses.insert(Use(emoji: emoji, count: count), at: 0)
        uses = Array(uses.prefix(Self.limit))
    }

    /// The most used first, the latest among equals.
    func frequent(limit: Int) -> [String] {
        uses.enumerated().sorted { ($0.element.count, -$0.offset) > ($1.element.count, -$1.offset) }
            .prefix(limit).map(\.element.emoji)
    }
}

/// The emoji counts this device wrote, until the store has them, and the change under way.
final class EmojiUseStates: @unchecked Sendable {
    /// Counts the server never confirms (another device changed them) are forgotten after this.
    private static let patience: TimeInterval = 60
    private let lock = NSLock()
    private var written: (uses: EmojiUses, since: Date)?
    private var changing: Task<Void, Error>?

    func uses(stored: EmojiUses) -> EmojiUses {
        lock.withLock {
            guard let written else { return stored }
            if written.uses == stored || Date().timeIntervalSince(written.since) > Self.patience {
                self.written = nil
                return stored
            }
            return written.uses
        }
    }

    func wrote(_ uses: EmojiUses?) {
        lock.withLock { written = uses.map { ($0, Date()) } }
    }

    func serially(_ work: @escaping @Sendable () async throws -> Void) async throws {
        let task: Task<Void, Error> = lock.withLock {
            let before = changing
            let next = Task {
                _ = try? await before?.value
                try await work()
            }
            changing = next
            return next
        }
        try await task.value
    }
}

extension Message {
    /// A deleted message: who sent it and when, without its content.
    init(deleted event: EventTimelineItem, id: String, senderName: String, senderPicture: String) {
        self.init(id: id, sender: event.sender, senderName: senderName, body: "", timestamp: event.timestamp,
                  isOwn: event.isOwn, sendState: .sent, image: nil, senderPicture: senderPicture)
        isDeleted = true
    }

    /// Your own text message, which the sdk can still edit; a photo's or file's caption is not
    /// offered.
    static func isEditable(_ event: EventTimelineItem, _ message: MessageContent) -> Bool {
        guard event.isOwn, event.isEditable, case .text = message.msgType else { return false }
        return true
    }
}

/// A sender's file name as one safe path component, or `fallback` when it has none.
private func shareName(_ name: String, fallback: String) -> String {
    let last = name.split(separator: "/").last.map(String.init) ?? ""
    let trimmed = last.trimmingCharacters(in: CharacterSet(charactersIn: ". ").union(.whitespacesAndNewlines))
    return trimmed.isEmpty ? fallback : trimmed
}
