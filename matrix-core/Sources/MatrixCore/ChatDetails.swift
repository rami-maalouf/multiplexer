import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// What a chat shows beside its messages' text (B15): who has read the chat how far, where its
/// unread messages start, videos and stickers, and the names a quote or a read receipt needs.

/// A video message's video (`MatrixAccount.videoPoster` and `videoFile` download it).
public struct MessageVideo: Equatable, Sendable {
    /// In pixels; 0 when the sender did not say.
    public var width: Int
    public var height: Int
    /// In milliseconds; 0 when the sender did not say.
    public var duration: Int
    /// The file name `videoPoster` gives its poster (the sender's still of it); "" when it has none.
    public var posterName: String
    /// The file name `videoFile` gives the video.
    public var fileName: String
    /// In bytes; 0 when the sender did not say.
    public var size: Int
    public var mimetype: String
}

/// Someone who has read a chat up to a message.
public struct MessageReader: Equatable, Sendable {
    public var userId: String
    /// Their name in the room; "" until the room's members are known.
    public var name: String
    /// When they read it, in milliseconds since 1970; nil when the server did not say.
    public var timestamp: UInt64?
}

/// The names of room members that a quote or a read receipt needs: the sdk gives a quoted
/// message and a receipt without their person's profile. A name comes from a message of
/// theirs in the chat, else from the room's members (`MatrixAccount.lookUpNames`).
final class MemberNames: @unchecked Sendable {
    private let lock = NSLock()
    private var known: [String: String] = [:]
    /// Asked for by a message and not looked up yet; being looked up; not found before the
    /// room's members loaded (looked up again once they have).
    private var wanted: Set<String> = [], lookingUp: Set<String> = [], notFound: Set<String> = []
    private var loaded = false

    /// Their name, or nil while it is not known (it is then looked up).
    func name(_ userId: String) -> String? {
        lock.withLock {
            if let name = known[userId] { return name }
            if !lookingUp.contains(userId) && !notFound.contains(userId) { wanted.insert(userId) }
            return nil
        }
    }

    /// A name a message of theirs carries.
    func learn(_ userId: String, _ name: String) {
        lock.withLock { known[userId] = name }
    }

    /// The ids to look up now; they are not asked for again until `found`.
    func take() -> [String] {
        lock.withLock {
            let ids = wanted
            wanted = []
            lookingUp.formUnion(ids)
            return Array(ids)
        }
    }

    /// The name the room's members give `userId`; nil when they give none. Once the members
    /// have loaded, someone with no name in the room is shown by their id, as clients do.
    func found(_ userId: String, _ name: String?) {
        lock.withLock {
            lookingUp.remove(userId)
            if let name, !name.isEmpty { known[userId] = name } else if loaded { known[userId] = userId } else { notFound.insert(userId) }
        }
    }

    /// The room's members have loaded: those not found before are looked up again.
    func membersLoaded() {
        lock.withLock {
            loaded = true
            wanted.formUnion(notFound)
            notFound = []
        }
    }
}

/// A timeline's items as the chat's messages, oldest first. Each message carries the read
/// receipts of others on it; a receipt on an event the chat does not show (a join, a new
/// name) counts for the message before it, as the sdk moves one off a hidden event.
func chatMessages(_ items: [TimelineItem], me: String, names: MemberNames) -> [Message] {
    // the names the timeline's own events carry: a quote or a receipt of the same person uses them.
    for item in items {
        if let event = item.asEvent(), case .ready(let name?, _, _, _, _) = event.senderProfile { names.learn(event.sender, name) }
    }
    var messages: [Message] = [], receipts: [[String: Receipt]] = []
    for item in items {
        guard let event = item.asEvent() else { continue }
        if let message = Message(event, id: item.uniqueId().id, me: me, names: names) {
            messages.append(message)
            receipts.append(event.readReceipts.filter { $0.key != me && $0.key != event.sender })
        } else if let last = messages.last {
            let others = event.readReceipts.filter { $0.key != me && $0.key != last.sender }
            receipts[receipts.count - 1].merge(others) { kept, _ in kept }
        }
    }
    for i in messages.indices {
        messages[i].readBy = receipts[i]
            .map { MessageReader(userId: $0.key, name: names.name($0.key) ?? "", timestamp: $0.value.timestamp) }
            .sorted { ($0.timestamp ?? 0, $0.userId) < ($1.timestamp ?? 0, $1.userId) }
    }
    return messages
}

/// The id of the first message from someone else after `receipt` (this account's read
/// receipt) and after this account's own last message, which reads what came before it.
/// When the receipt's event is not in the timeline (older, or a reaction), the messages sent
/// after the receipt's time count. Nil for none, and when there is no receipt at all.
func firstUnreadItem(_ items: [TimelineItem], me: String, receipt: UserReceipt?) -> String? {
    guard let receipt else { return nil }
    func isEvent(_ item: TimelineItem, _ eventId: String) -> Bool {
        if case .eventId(eventId)? = item.asEvent()?.eventOrTransactionId { return true }
        return false
    }
    let receiptIndex = items.firstIndex { isEvent($0, receipt.eventId) }
    let ownIndex = items.lastIndex { item in item.asEvent().map { $0.sender == me && isShown($0) } ?? false }
    let from = [receiptIndex, ownIndex].compactMap { $0 }.max()
    let ownTime = ownIndex.flatMap { items[$0].asEvent()?.timestamp } ?? 0
    for (index, item) in items.enumerated() {
        guard let event = item.asEvent(), event.sender != me, isShown(event) else { continue }
        if receiptIndex != nil, let from {
            if index > from { return item.uniqueId().id }
        } else if event.timestamp > max(receipt.receipt.timestamp ?? UInt64.max, ownTime), ownIndex.map({ index > $0 }) ?? true {
            return item.uniqueId().id
        }
    }
    return nil
}

/// An event the chat shows as a message (`Message.init`).
private func isShown(_ event: EventTimelineItem) -> Bool {
    guard case .msgLike(let like) = event.content else { return false }
    switch like.kind {
    case .message, .sticker, .unableToDecrypt: return true
    default: return false
    }
}

extension MatrixAccount {
    /// Looks up the names a quote or a read receipt asked for, among the room's members; the
    /// chat changes when they are found.
    func lookUpNames(_ roomId: String, _ names: MemberNames) {
        let ids = names.take()
        guard !ids.isEmpty, let room = try? client.getRoom(roomId: roomId) else { return }
        Task {
            for id in ids { names.found(id, (try? await room.memberDisplayName(userId: id)) ?? nil) }
            notify(.room(roomId))
        }
    }

    /// The first unread message of an open chat, by its id: the first message from someone
    /// else after this account's read receipt (from any of its devices; a bridge's double
    /// puppet sends one when the chat is read on its network). When it is older than what the
    /// chat shows, the chat pages back once to the receipt's message (at most `pageLimit`
    /// events) and shows from a few messages before it, so the "New" line has its place. Nil
    /// when the room counts no unread message, or the first unread one is further back.
    public func firstUnread(roomId: String, pageLimit: Int = 300, timeout: TimeInterval = 30) async throws -> String? {
        let target = try await room(roomId, timeout: timeout)
        guard let info = try? await target.roomInfo(), info.numUnreadMessages > 0 else { return nil }
        let me = try client.userId()
        var latest: UserReceipt?
        for type in [ReceiptType.read, .readPrivate] {
            for thread in [ReceiptThread.unthreaded, .main] {
                guard let receipt = try? await target.loadUserReceipt(receiptType: type, thread: thread, userId: me) else { continue }
                if (receipt.receipt.timestamp ?? 0) >= (latest?.receipt.timestamp ?? 0) { latest = receipt }
            }
        }
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        func shownFirstUnread() -> String? {
            let found = live.items.read { items, me in firstUnreadItem(items, me: me, receipt: latest) }
            // one the chat does not show yet (older than its first shown message) has no line.
            guard let found, live.shown(limit: 20).contains(where: { $0.id == found }) else { return nil }
            return found
        }
        if let found = shownFirstUnread() { return found }
        // a few read messages above the line, more than half a screen, so the chat placed at the
        // line does not start at the top of what it shows.
        guard let latest, try await live.pageBackOnce(toEvent: latest.eventId, context: 8, limit: pageLimit) else { return nil }
        // the chat shows more now: no change of the timeline's says so.
        notify(.room(roomId))
        return shownFirstUnread()
    }

    /// A video message's poster (the sender's still of it) as a file in `directory`. Downloaded
    /// once; later calls return the same file. Throws `noVideo` when it has none.
    public func videoPoster(roomId: String, messageId: String, directory: URL, timeout: TimeInterval = 30) async throws -> URL {
        let (content, video) = try await videoContent(roomId: roomId, messageId: messageId, timeout: timeout)
        guard let source = content.info?.thumbnailSource, !video.posterName.isEmpty else { throw MatrixCoreError.noVideo(messageId) }
        let file = directory.appendingPathComponent(video.posterName)
        if FileManager.default.fileExists(atPath: file.path) { return file }
        let data = try await client.getMediaContent(mediaSource: source)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
        return file
    }

    /// A video message's video as a file in `directory`, to play. Downloaded once, straight to
    /// a file (a video can be large); later calls return the same file.
    public func videoFile(roomId: String, messageId: String, directory: URL, timeout: TimeInterval = 30) async throws -> URL {
        let (content, video) = try await videoContent(roomId: roomId, messageId: messageId, timeout: timeout)
        let file = directory.appendingPathComponent(video.fileName)
        if FileManager.default.fileExists(atPath: file.path) { return file }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let handle = try await client.getMediaFile(mediaSource: content.source, filename: nil,
                                                   mimeType: video.mimetype.isEmpty ? "video/mp4" : video.mimetype,
                                                   useCache: false, tempDir: directory.path)
        if try !handle.persist(path: file.path) {
            try FileManager.default.copyItem(atPath: try handle.path(), toPath: file.path)
        }
        return file
    }

    private func videoContent(roomId: String, messageId: String, timeout: TimeInterval) async throws -> (VideoMessageContent, MessageVideo) {
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        // a video of the info page's grid is in the chat's media timeline.
        guard let event = await (mediaItems(roomId, for: messageId) ?? live.items).event(of: messageId), case .msgLike(let like) = event.content,
              case .message(let message) = like.kind, case .video(let content) = message.msgType else {
            throw MatrixCoreError.noVideo(messageId)
        }
        return (content, MessageVideo(content))
    }
}

extension MessageVideo {
    init(_ content: VideoMessageContent) {
        let key = mediaKey(content.source.url())
        let mimetype = content.info?.mimetype ?? ""
        let ext: String
        switch mimetype {
        case "video/quicktime": ext = "mov"
        case "video/webm": ext = "webm"
        case "video/3gpp": ext = "3gp"
        default: ext = "mp4"
        }
        self.init(width: Int(content.info?.width ?? 0), height: Int(content.info?.height ?? 0),
                  duration: Int(((content.info?.duration ?? 0) * 1000).rounded()),
                  posterName: content.info?.thumbnailSource == nil ? "" : "\(key)-poster.jpg",
                  fileName: "\(key).\(ext)", size: Int(content.info?.size ?? 0), mimetype: mimetype)
    }
}

extension MessageImage {
    init(sticker info: ImageInfo, source: MediaSource) {
        let key = mediaKey(source.url())
        let ext: String
        switch info.mimetype {
        case "image/png"?: ext = "png"
        case "image/gif"?: ext = "gif"
        case "image/jpeg"?: ext = "jpg"
        default: ext = "webp"
        }
        self.init(width: Int(info.width ?? 0), height: Int(info.height ?? 0),
                  thumbnailName: "\(key)-sticker.\(ext)", fullName: "\(key)-sticker.\(ext)", isSticker: true)
    }
}
