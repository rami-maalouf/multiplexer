import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// A chat's info page (B20): what it is, who is in it, its recent photos and videos, its name and
/// picture, and the name only this account sees (Customize for Me).

/// A chat as its info page shows it.
public struct ChatInfo: Equatable, Sendable {
    public var id: String
    /// The name the chat shows: the account's own name for it when it has one (`customName`).
    public var name: String
    /// The name everyone in the chat sees (the room's own, or the one the server makes of its
    /// members when it has none).
    public var roomName: String
    /// The name only this account sees (`setCustomName`); "" for none.
    public var customName: String
    public var topic: String
    /// The room's picture as a media url for `MatrixAccount.chatPicture`; "" when it has none.
    public var pictureUrl: String
    public var network: String
    /// A chat with one other person, as the filter menu counts one (`RoomSummary.isOneToOne`).
    public var isOneToOne: Bool
    /// The people who have joined, the bridge's bot left out.
    public var memberCount: Int
    /// This account may change the room's name, picture, or invite someone.
    public var canRename: Bool
    public var canChangePicture: Bool
    public var canInvite: Bool
}

/// Someone in a chat.
public struct ChatMember: Equatable, Sendable {
    public var userId: String
    /// Their name in the room; their id when they have none.
    public var name: String
    /// Their picture as a media url for `MatrixAccount.pictureFile`; "" when they have none.
    public var pictureUrl: String
    public var isOwn: Bool
}

/// A photo or a video of a chat, for its info page's grid.
public struct ChatMedia: Equatable, Sendable {
    /// The item's id in the chat's media timeline: `imageFile`, `videoPoster` and `videoFile`
    /// take it as they take a message's.
    public var id: String
    public var isVideo: Bool
    public var timestamp: UInt64
    public var senderName: String
    public var isOwn: Bool
    public var caption: String
    /// In pixels; 0 when the sender did not say.
    public var width: Int
    public var height: Int
    /// The file name of its picture: a photo's thumbnail (`imageFile`), a video's poster
    /// (`videoPoster`); "" for a video with no poster.
    public var thumbnailName: String
    /// A video's length in milliseconds; 0 for a photo.
    public var duration: Int
}

extension MatrixAccount {
    /// What the chat's info page shows of it.
    public func chatInfo(roomId: String, timeout: TimeInterval = 30) async throws -> ChatInfo {
        let target = try await room(roomId, timeout: timeout)
        let info = try await target.roomInfo()
        let me = try client.userId()
        let levels = try? await target.getPowerLevels()
        let custom = await customNames()[roomId] ?? ""
        let roomName = target.displayName() ?? roomId
        // the bot of a bridge is a service member (`io.element.functional_members`).
        let service = UInt64(info.serviceMembers.count)
        var summary = RoomSummary(id: roomId, name: roomName, isDirect: await target.isDirect(), lastMessage: "",
                                  lastSenderName: "", lastIsOwn: false, lastTimestamp: 0)
        summary.fillKind(info, pins: pins)
        return ChatInfo(id: roomId, name: custom.isEmpty ? roomName : custom, roomName: roomName, customName: custom,
                        topic: info.topic ?? "", pictureUrl: target.avatarUrl() ?? "",
                        network: RoomNetwork.of(info, ownUserId: me), isOneToOne: summary.isOneToOne,
                        memberCount: Int(info.joinedMembersCount > service ? info.joinedMembersCount - service : 0),
                        canRename: levels?.canOwnUserSendState(stateEvent: .roomName) ?? false,
                        canChangePicture: levels?.canOwnUserSendState(stateEvent: .roomAvatar) ?? false,
                        canInvite: levels?.canOwnUserInvite() ?? false)
    }

    /// The people who have joined the chat, by name; a bridge's bot is left out.
    public func chatMembers(roomId: String, timeout: TimeInterval = 30) async throws -> [ChatMember] {
        let target = try await room(roomId, timeout: timeout)
        let info = try await target.roomInfo()
        let me = try client.userId()
        let iterator = try await target.members()
        var members: [ChatMember] = []
        while let chunk = iterator.nextChunk(chunkSize: 200) {
            for member in chunk where member.membership == .join && !member.isServiceMember
                && !info.serviceMembers.contains(member.userId) {
                let name = member.displayName.flatMap { $0.isEmpty ? nil : $0 } ?? member.userId
                members.append(ChatMember(userId: member.userId, name: name, pictureUrl: member.avatarUrl ?? "",
                                          isOwn: member.userId == me))
            }
        }
        return members.sorted { ($0.name.localizedLowercase, $0.userId) < ($1.name.localizedLowercase, $1.userId) }
    }

    /// The chat's newest photos and videos, the newest first, at most `limit`. The chat's media
    /// timeline (a timeline of only `m.image` and `m.video` messages) pages back from the server
    /// until it holds `limit` or reaches the room's start; it stays open, so a new one shows and
    /// the info page is told (`MatrixChange.info`).
    public func recentMedia(roomId: String, limit: Int, timeout: TimeInterval = 30) async throws -> [ChatMedia] {
        let live = try await mediaTimeline(roomId, timeout: timeout)
        try await live.pageBackMedia(until: limit)
        let me = (try? client.userId()) ?? ""
        // a deleted chat's older photos went with it.
        let cut = await chatMarks().cleared[roomId] ?? 0
        return live.items.read { items, _ in
            items.reversed().filter { ($0.asEvent()?.timestamp ?? 0) > cut }
                .compactMap { ChatMedia($0, me: me) }.prefix(limit).map { $0 }
        }
    }

    /// The chat's media timeline, opened once.
    func mediaTimeline(_ roomId: String, timeout: TimeInterval) async throws -> MediaTimeline {
        let opening = infoStates.timeline(roomId) {
            try await self.openTimeline(roomId, types: [.image, .video], prefix: MediaTimeline.prefix, change: .info(roomId), timeout: timeout)
        }
        do {
            return try await opening.value
        } catch {
            infoStates.forgetTimeline(roomId)
            throw error
        }
    }

    /// A live timeline of the chat with only messages of `types`, its items' ids starting with
    /// `prefix`; a change of its items tells `change`.
    func openTimeline(_ roomId: String, types: [RoomMessageEventMessageType], prefix: String, change: MatrixChange,
                      timeout: TimeInterval) async throws -> MediaTimeline {
        let timeline = try await room(roomId, timeout: timeout).timelineWithConfiguration(configuration: TimelineConfiguration(
            focus: .live(hideThreadedEvents: false), filter: .onlyMessage(types: types),
            internalIdPrefix: prefix, dateDividerMode: .monthly, trackReadReceipts: .disabled, reportUtds: false))
        let items = TimelineItems(me: (try? client.userId()) ?? "")
        let handle = await timeline.addListener(listener: items)
        items.onChange = { [weak self] in self?.notify(change) }
        return MediaTimeline(timeline: timeline, items: items, handle: handle)
    }

    /// The items of the chat's media timeline once it is open, for a photo or video of its grid
    /// (an id with `MediaTimeline.prefix`); nil for another id, and before.
    func mediaItems(_ roomId: String, for itemId: String) async -> TimelineItems? {
        guard itemId.hasPrefix(MediaTimeline.prefix), let task = infoStates.openedTimeline(roomId) else { return nil }
        return try? await task.value.items
    }

    /// The room's picture as a file in `directory`, at most `side` pixels a side, larger than the
    /// list's (`avatarFile`); nil when it has none. Downloaded once.
    public func chatPicture(roomId: String, directory: URL, side: UInt64 = 480) async throws -> URL? {
        guard let url = try client.getRoom(roomId: roomId)?.avatarUrl() else { return nil }
        return try await pictureFile(url: url, directory: directory, side: side, name: Self.largePictureName(url))
    }

    /// The file name `chatPicture` gives a room's picture.
    public static func largePictureName(_ url: String) -> String { url.isEmpty ? "" : "\(mediaKey(url))-picture.jpg" }

    /// Renames the chat for everyone in it. A bridge passes the name to the chat's network.
    public func setRoomName(roomId: String, name: String, timeout: TimeInterval = 30) async throws {
        try await room(roomId, timeout: timeout).setName(name: name)
    }

    /// Gives the chat a new picture for everyone in it: a JPEG or PNG on this device.
    public func setRoomPicture(roomId: String, file: URL, mimetype: String, width: Int, height: Int,
                               timeout: TimeInterval = 30) async throws {
        let data = try Data(contentsOf: file)
        let info = ImageInfo(height: UInt64(height), width: UInt64(width), mimetype: mimetype, size: UInt64(data.count),
                             thumbnailInfo: nil, thumbnailSource: nil, blurhash: nil, isAnimated: false)
        try await room(roomId, timeout: timeout).uploadAvatar(mimeType: mimetype, data: data, mediaInfo: info)
    }

    /// Invites someone (a Matrix user id) to the chat.
    public func invite(roomId: String, userId: String, timeout: TimeInterval = 30) async throws {
        try await room(roomId, timeout: timeout).inviteUserById(userId: userId)
    }

    /// Gives the chat a name only this account sees, on all its devices (`ChatInfo.customName`);
    /// "" takes it away. The list and the chat show it in place of the room's name.
    public func setCustomName(roomId: String, name: String, timeout: TimeInterval = 30) async throws {
        _ = try await room(roomId, timeout: timeout)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try await infoStates.serially {
            // the store's names, else the server's: a new device must not start from none.
            var names = self.infoStates.names(stored: CustomNames.names(json: try await self.accountDataForChange(CustomNames.type)))
            names[roomId] = trimmed.isEmpty ? nil : trimmed
            self.infoStates.wrote(names)
            self.notify(.rooms)
            self.notify(.info(roomId))
            do {
                try await self.client.setAccountData(eventType: CustomNames.type, content: CustomNames.json(names))
            } catch {
                self.infoStates.wrote(nil)
                self.notify(.rooms)
                self.notify(.info(roomId))
                throw error
            }
        }
    }

    /// The names only this account sees, by room: those this device just wrote until the store
    /// has them, else the store's.
    func customNames() async -> [String: String] {
        let stored = CustomNames.names(json: (try? await client.accountData(eventType: CustomNames.type)) ?? nil)
        return infoStates.names(stored: stored)
    }

    /// Each chat shows the account's own name for it, if it has one.
    func fillCustomNames(_ rooms: inout [RoomSummary]) async {
        let names = await customNames()
        for i in rooms.indices {
            rooms[i].roomName = rooms[i].name
            if let name = names[rooms[i].id] { rooms[i].name = name }
        }
    }
}

/// The names only this account sees: one global account data event, which no bridge reads.
enum CustomNames {
    static let type = "com.ramimaalouf.multiplexer.names"

    /// From the event's content, `{"names": {"<room id>": "<name>"}}`; empty for none.
    static func names(json: String?) -> [String: String] {
        guard let data = json?.data(using: .utf8),
              let content = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return [:] }
        return ((content["names"] as? [String: Any]) ?? [:]).compactMapValues { ($0 as? String).flatMap { $0.isEmpty ? nil : $0 } }
    }

    static func json(_ names: [String: String]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: ["names": names], options: [.sortedKeys])) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}

/// The info page's own state: each chat's media timeline, and the names this device wrote and the
/// server has not confirmed.
final class ChatInfoStates: @unchecked Sendable {
    private static let patience: TimeInterval = 30
    private let lock = NSLock()
    private var timelines: [String: Task<MediaTimeline, Error>] = [:]
    private var written: (names: [String: String], since: Date)?
    private var changing: Task<Void, Error>?

    /// The chat's media timeline: the one opening or open, else the one `open` starts.
    func timeline(_ roomId: String, open: @escaping @Sendable () async throws -> MediaTimeline) -> Task<MediaTimeline, Error> {
        lock.withLock {
            if let made = timelines[roomId] { return made }
            let task = Task { try await open() }
            timelines[roomId] = task
            return task
        }
    }

    func openedTimeline(_ roomId: String) -> Task<MediaTimeline, Error>? { lock.withLock { timelines[roomId] } }

    func forgetTimeline(_ roomId: String) { lock.withLock { timelines[roomId] = nil } }
    func forgetAll() { lock.withLock { timelines = [:] } }

    func names(stored: [String: String]) -> [String: String] {
        lock.withLock {
            guard let written else { return stored }
            if written.names == stored || Date().timeIntervalSince(written.since) > Self.patience {
                self.written = nil
                return stored
            }
            return written.names
        }
    }

    func wrote(_ names: [String: String]?) {
        lock.withLock { written = names.map { ($0, Date()) } }
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

/// A chat's timeline of only some kinds of message (its photos and videos for the info page; a
/// kind for the search in the chat), and its listener.
final class MediaTimeline: @unchecked Sendable {
    /// Its items' ids start with this, so a photo of the grid is not taken for a message's.
    static let prefix = "media-"
    let timeline: Timeline
    let items: TimelineItems
    private let handle: TaskHandle
    private let lock = NSLock()
    /// The items' reset count when a page back reached the room's start: a reset since (a sync
    /// with a gap leaves only the newest events) makes the start unknown again.
    private var startAtReset: Int?

    init(timeline: Timeline, items: TimelineItems, handle: TaskHandle) {
        self.timeline = timeline
        self.items = items
        self.handle = handle
    }

    private var reachedStart: Bool { lock.withLock { startAtReset } == items.resetCount }

    /// Pages back until it holds `count` photos and videos or the room's start; at most 8 pages
    /// of 50 events, since most of a chat's events are no photo.
    func pageBackMedia(until count: Int) async throws {
        try await pageBack(until: count, pages: 8) { self.items.read { items, _ in items.filter { $0.asEvent() != nil }.count } }
    }

    /// Pages back until `held` counts `count` or the room's start, at most `pages` pages of 50 events.
    func pageBack(until count: Int, pages: Int, held: () -> Int) async throws {
        for _ in 0..<pages {
            await items.settle(quiet: 0.3)
            if reachedStart || held() >= count { return }
            let resets = items.resetCount
            let start = try await timeline.paginateBackwards(numEvents: 50)
            lock.withLock { startAtReset = start ? resets : nil }
        }
        await items.settle(quiet: 0.3)
    }

    deinit { handle.cancel() }
}

extension ChatMedia {
    init?(_ item: TimelineItem, me: String) {
        guard let event = item.asEvent(), case .msgLike(let like) = event.content, case .message(let message) = like.kind else { return nil }
        var name = event.sender
        if case .ready(let shown?, _, _, _, _) = event.senderProfile { name = shown }
        switch message.msgType {
        case .image(let content):
            let image = MessageImage(content)
            self.init(id: item.uniqueId().id, isVideo: false, timestamp: event.timestamp, senderName: name, isOwn: event.sender == me,
                      caption: content.caption ?? "", width: image.width, height: image.height, thumbnailName: image.thumbnailName, duration: 0)
        case .video(let content):
            let video = MessageVideo(content)
            self.init(id: item.uniqueId().id, isVideo: true, timestamp: event.timestamp, senderName: name, isOwn: event.sender == me,
                      caption: content.caption ?? "", width: video.width, height: video.height, thumbnailName: video.posterName,
                      duration: video.duration)
        default:
            return nil
        }
    }
}

extension ChatMember {
    /// The file name `MatrixAccount.pictureFile` gives their picture; "" when they have none.
    public var pictureName: String { pictureUrl.isEmpty ? "" : avatarFileName(pictureUrl) }
}
