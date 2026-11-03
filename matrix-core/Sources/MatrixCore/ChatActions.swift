import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// A chat's long-press actions: mark unread, mute, Low Priority, Archive and Delete (from this
/// app only). How each is kept on the server, and why: `matrix-core/NOTES.md`, "A chat's actions".
extension MatrixAccount {
    /// Marks a chat unread by hand (`m.marked_unread`), or takes the mark away. Reading the chat
    /// (`markRead`) takes it away too.
    public func setMarkedUnread(roomId: String, _ unread: Bool, timeout: TimeInterval = 30) async throws {
        let target = try await room(roomId, timeout: timeout)
        try await expecting(.markedUnread, roomId, unread) { try await target.setUnreadFlag(newValue: unread) }
    }

    /// Mutes a chat: its messages notify nothing (the room's override push rule with no actions, as
    /// Element mutes). A message that mentions this account is still highlighted, without a
    /// notification, so the list can show it (`RoomSummary.unreadMentions`).
    public func mute(roomId: String, timeout: TimeInterval = 30) async throws {
        _ = try await room(roomId, timeout: timeout)
        let me = try client.userId()
        try await expecting(.muted, roomId, true) {
            let settings = await self.notificationSettings()
            // the mute first: setting it removes the room's other rules, and a mention rule alone
            // would already read as muted.
            try await settings.setRoomNotificationMode(roomId: roomId, mode: .mute)
            // a new rule goes first, so a mention matches it before the mute.
            try await settings.setCustomPushRule(
                ruleId: Self.mentionRule(roomId), ruleKind: .override,
                actions: [.setTweak(value: .highlight(value: true))],
                conditions: [.eventMatch(key: "room_id", pattern: roomId),
                             .eventPropertyContains(key: "content.m\\.mentions.user_ids", value: .string(value: me))])
        }
    }

    /// Unmutes a chat, muted here or elsewhere (a bridge mutes a chat muted on its network with a
    /// room rule that leaves mentions, which the sdk calls mentions only): the room's own rules go,
    /// so it follows the account's default again. An archived chat stays archived until its next
    /// message.
    public func unmute(roomId: String, timeout: TimeInterval = 30) async throws {
        let target = try await room(roomId, timeout: timeout)
        let info = try await target.roomInfo()
        // the messages that came while it was muted do not bring it back: first, so it stays.
        if await chatMarks().archived[roomId] != nil {
            let newest = await newestTimestamp(target)
            try await changeMarks { $0.archived[roomId] = newest }
        }
        try await expecting(.muted, roomId, false) {
            let settings = await self.notificationSettings()
            let usual = await settings.getDefaultRoomNotificationMode(
                isEncrypted: info.encryptionState != .notEncrypted, isOneToOne: info.activeMembersCount == 2)
            if usual == .mute {
                try await settings.setRoomNotificationMode(roomId: roomId, mode: .allMessages)
            } else {
                try await settings.restoreDefaultRoomNotificationMode(roomId: roomId)
            }
        }
    }

    /// Moves a chat to Low Priority (`m.lowpriority`), or back to the inbox. A pinned chat is
    /// unpinned: the sdk keeps the two tags apart.
    public func setLowPriority(roomId: String, _ low: Bool, timeout: TimeInterval = 30) async throws {
        let target = try await room(roomId, timeout: timeout)
        if low {
            pins.expect(roomId, pinned: false)
            pins.forget(roomId)
        }
        do {
            try await expecting(.lowPriority, roomId, low) { try await target.setIsLowPriority(isLowPriority: low, tagOrder: nil) }
        } catch {
            if low { pins.expect(roomId, pinned: nil) }
            throw error
        }
    }

    /// Archives a chat: it leaves the inbox for the Archive list until a newer message comes,
    /// unless it is muted.
    public func archive(roomId: String, timeout: TimeInterval = 30) async throws {
        let newest = await newestTimestamp(try await room(roomId, timeout: timeout))
        try await changeMarks { $0.archived[roomId] = newest }
    }

    public func unarchive(roomId: String, timeout: TimeInterval = 30) async throws {
        _ = try await room(roomId, timeout: timeout)
        try await changeMarks { $0.archived[roomId] = nil }
    }

    /// Deletes a chat from this app only: it shows nowhere, on any of the account's devices, until
    /// a newer message comes, and then only the messages after the delete. The room stays joined,
    /// so the chat stays on its network: a bridge that is told the account left can leave the
    /// group there (`NOTES.md`).
    public func hide(roomId: String, timeout: TimeInterval = 30) async throws {
        let newest = await newestTimestamp(try await room(roomId, timeout: timeout))
        try await changeMarks {
            $0.hidden[roomId] = newest
            $0.cleared[roomId] = newest
        }
        readyTimeline(roomId)?.items.since = newest
    }

    /// The archive and delete marks: those this device just wrote until the server has them,
    /// else the store's.
    func chatMarks() async -> ChatMarks {
        let stored = ChatMarks(json: (try? await client.accountData(eventType: ChatMarks.type)) ?? nil)
        return chats.marks(stored: stored)
    }

    /// Whether each chat is muted, then whether it is archived or deleted now: a mark holds only
    /// until a newer message, unless the chat is muted and that message is not our own.
    func fillChatStates(_ rooms: inout [RoomSummary]) async {
        let quiet = await quietRooms()
        let marks = await chatMarks()
        var returned = false
        for i in rooms.indices {
            rooms[i].isMuted = chats.value(.muted, of: rooms[i].id, onServer: quiet.contains(rooms[i].id))
            rooms[i].fillMarks(marks)
            if rooms[i].isMuted, let ts = marks.archived[rooms[i].id], !rooms[i].isArchived, rooms[i].lastTimestamp > ts { returned = true }
        }
        // our own message brought a muted chat back: its mark goes, so the next message from
        // someone else does not archive it again.
        if returned, chats.startDropping() {
            Task {
                try? await self.changeMarks { _ in }
                self.chats.doneDropping()
            }
        }
    }

    /// The chats whose messages do not notify: muted, or left to mentions only (a bridge mutes
    /// that way). The sdk's `RoomInfo.cachedUserDefinedNotificationMode` is not kept across
    /// launches, so this reads the push rules themselves.
    private func quietRooms() async -> Set<String> {
        let settings = await notificationSettings()
        var quiet = Set<String>()
        for roomId in await settings.getRoomsWithUserDefinedRules(enabled: true) {
            switch try? await settings.getUserDefinedRoomNotificationMode(roomId: roomId) {
            case .mute?, .mentionsAndKeywordsOnly?: quiet.insert(roomId)
            default: break
            }
        }
        return quiet
    }

    /// The account's push rules: read once from the store, then kept current by the sync and by
    /// this device's own changes. A change from another device tells the list.
    func notificationSettings() async -> NotificationSettings {
        await chats.settings {
            let settings = await self.client.getNotificationSettings()
            settings.setDelegate(delegate: SettingsChanged { [weak self] in self?.notify(.rooms) })
            return settings
        }
    }

    /// The push rule that keeps a muted chat's mentions; the room's own rules, so unmuting removes it.
    static func mentionRule(_ roomId: String) -> String { "com.ramimaalouf.multiplexer.mention.\(roomId)" }

    /// Shows `value` at once, writes it, and forgets it again if the server refused.
    private func expecting(_ field: ChatStates.Field, _ roomId: String, _ value: Bool,
                           _ write: @escaping () async throws -> Void) async throws {
        chats.expect(field, roomId, value)
        notify(.rooms)
        do {
            try await write()
        } catch {
            chats.expect(field, roomId, nil)
            notify(.rooms)
            throw error
        }
    }

    /// Changes the marks one change at a time, from the newest this device knows, so two changes
    /// in a row both stay. Marks whose chat came back are dropped on the way.
    private func changeMarks(_ change: @escaping @Sendable (inout ChatMarks) -> Void) async throws {
        try await chats.serially {
            let before = await self.chatMarks()
            var marks = before
            change(&marks)
            marks.dropReturned(try await self.rooms())
            if marks == before { return }
            self.chats.wrote(marks)
            self.notify(.rooms)
            do {
                try await self.client.setAccountData(eventType: ChatMarks.type, content: marks.json())
            } catch {
                self.chats.wrote(nil)
                self.notify(.rooms)
                throw error
            }
        }
    }

    /// The time of the chat's newest message (or own join): what a later message is newer than.
    private func newestTimestamp(_ room: Room) async -> UInt64 {
        switch await room.latestEvent() {
        case .remote(let timestamp, _, _, _, _), .local(let timestamp, _, _, _, _): return timestamp
        case .none, .remoteInvite: return 0
        }
    }
}

extension RoomSummary {
    /// What the room list service knows of the chat's actions, with this device's own changes
    /// shown before the server confirms them.
    mutating func fillActions(_ info: RoomInfo, chats: ChatStates) {
        unreadMentions = Int(info.numUnreadMentions)
        isLowPriority = chats.value(.lowPriority, of: id, onServer: info.isLowPriority)
        isMarkedUnread = chats.value(.markedUnread, of: id, onServer: info.isMarkedUnread)
    }

    /// Archived until a newer message (a muted chat stays), deleted until a newer message.
    mutating func fillMarks(_ marks: ChatMarks) {
        isArchived = marks.archived[id].map { lastTimestamp <= $0 || (isMuted && !lastIsOwn) } ?? false
        isHidden = marks.hidden[id].map { lastTimestamp <= $0 } ?? false
    }
}

/// The chats this account archived or deleted, each with the time of its newest message then.
/// One global account data event (`type`) holds them: the sdk reads it from its store, and no
/// bridge reads it, so neither reaches the chat's network.
struct ChatMarks: Equatable, Sendable {
    static let type = "com.ramimaalouf.multiplexer.chats"

    var archived: [String: UInt64] = [:]
    var hidden: [String: UInt64] = [:]
    /// The time of each deleted chat's newest message at its delete, kept after it comes back:
    /// the chat shows only the messages after it.
    var cleared: [String: UInt64] = [:]
    /// The content's other keys, from a later version of the app, kept as they are.
    private var other: String = "{}"

    init(archived: [String: UInt64] = [:], hidden: [String: UInt64] = [:], cleared: [String: UInt64] = [:]) {
        self.archived = archived
        self.hidden = hidden
        self.cleared = cleared
    }

    /// From the event's content (`{"archived": {"<room id>": {"ts": <ms>}}, "hidden": {...},
    /// "cleared": {...}}`);
    /// empty for none.
    init(json: String?) {
        guard let data = json?.data(using: .utf8),
              var content = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
        func times(_ key: String) -> [String: UInt64] {
            ((content.removeValue(forKey: key) as? [String: Any]) ?? [:]).compactMapValues {
                (($0 as? [String: Any])?["ts"] as? NSNumber)?.uint64Value
            }
        }
        archived = times("archived")
        hidden = times("hidden")
        cleared = times("cleared")
        other = (try? JSONSerialization.data(withJSONObject: content)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    func json() -> String {
        var content = (other.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
        content["archived"] = archived.mapValues { ["ts": $0] }
        content["hidden"] = hidden.mapValues { ["ts": $0] }
        content["cleared"] = cleared.mapValues { ["ts": $0] }
        let data = (try? JSONSerialization.data(withJSONObject: content, options: [.sortedKeys])) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self)
    }

    /// Drops the marks of chats a newer message brought back (a muted chat's only by our own); a
    /// chat not in `rooms` keeps its mark. A delete's cut stays.
    mutating func dropReturned(_ rooms: [RoomSummary]) {
        for room in rooms {
            if let ts = archived[room.id], !room.isMuted || room.lastIsOwn, room.lastTimestamp > ts { archived[room.id] = nil }
            if let ts = hidden[room.id], room.lastTimestamp > ts { hidden[room.id] = nil }
        }
    }

    static func == (a: ChatMarks, b: ChatMarks) -> Bool { a.archived == b.archived && a.hidden == b.hidden && a.cleared == b.cleared }
}

/// What this device asked for and the server has not confirmed yet, so the list shows it at once.
final class ChatStates: @unchecked Sendable {
    enum Field: Hashable { case markedUnread, muted, lowPriority }

    /// An answer the server never gives (another device changed it back) is forgotten after this.
    private static let patience: TimeInterval = 30
    private let lock = NSLock()
    private var expected: [Field: [String: (value: Bool, since: Date)]] = [:]
    /// The marks this device last wrote, until the store has them.
    private var written: (marks: ChatMarks, since: Date)?
    /// The change of marks under way: the next one waits for it.
    private var changing: Task<Void, Error>?
    /// A change that drops the marks of chats that came back is under way.
    private var dropping = false
    /// The account's push rules (`MatrixAccount.notificationSettings`), made once.
    private var notificationSettings: Task<NotificationSettings, Never>?

    /// The value to show: as asked here, until the server says the same.
    func value(_ field: Field, of roomId: String, onServer: Bool) -> Bool {
        lock.withLock {
            guard let wanted = expected[field]?[roomId] else { return onServer }
            if wanted.value == onServer || Date().timeIntervalSince(wanted.since) > Self.patience {
                expected[field]?[roomId] = nil
                return onServer
            }
            return wanted.value
        }
    }

    /// Records a change asked for here; nil forgets it (the server refused it).
    func expect(_ field: Field, _ roomId: String, _ value: Bool?) {
        lock.withLock { expected[field, default: [:]][roomId] = value.map { ($0, Date()) } }
    }

    func marks(stored: ChatMarks) -> ChatMarks {
        lock.withLock {
            guard let written else { return stored }
            if written.marks == stored || Date().timeIntervalSince(written.since) > Self.patience {
                self.written = nil
                return stored
            }
            return written.marks
        }
    }

    /// True when no drop is under way, which the caller then starts.
    func startDropping() -> Bool {
        lock.withLock {
            if dropping { return false }
            dropping = true
            return true
        }
    }

    func doneDropping() { lock.withLock { dropping = false } }

    func wrote(_ marks: ChatMarks?) {
        lock.withLock { written = marks.map { ($0, Date()) } }
    }

    func settings(_ make: @escaping @Sendable () async -> NotificationSettings) async -> NotificationSettings {
        let task: Task<NotificationSettings, Never> = lock.withLock {
            if let made = notificationSettings { return made }
            let making = Task { await make() }
            notificationSettings = making
            return making
        }
        return await task.value
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

/// Tells the list when the account's push rules change.
private final class SettingsChanged: NotificationSettingsDelegate, @unchecked Sendable {
    private let changed: @Sendable () -> Void

    init(_ changed: @escaping @Sendable () -> Void) { self.changed = changed }

    func settingsDidChange() { changed() }
}
