import Foundation
import Darwin
import MatrixCore

public struct Failure: Error, CustomStringConvertible {
    public var description: String
    public init(_ description: String) { self.description = description }
}

/// one chat as mx prints it: plain fields, stable names, for agents to parse.
public struct Chat: Encodable {
    public var id: String
    public var roomIds: [String]
    public var name: String
    public var network: String
    public var isDirect: Bool
    public var unread: Int
    public var mentions: Int
    public var markedUnread: Bool
    public var muted: Bool
    public var archived: Bool
    public var pinned: Bool
    public var lastMessage: String
    public var lastSender: String
    public var lastIsOwn: Bool
    /// milliseconds since 1970; 0 when the chat has no message.
    public var lastTimestamp: UInt64

    public init(_ room: RoomSummary) {
        id = room.id
        roomIds = room.mergeRooms.isEmpty ? [room.id] : room.mergeRooms.map(\.id)
        name = room.name
        network = room.network
        isDirect = room.isDirect
        unread = room.unreadCount
        mentions = room.unreadMentions
        markedUnread = room.isMarkedUnread
        muted = room.isMuted
        archived = room.isArchived
        pinned = room.isPinned
        lastMessage = room.lastMessage
        lastSender = room.lastSenderName
        lastIsOwn = room.lastIsOwn
        lastTimestamp = room.lastTimestamp
    }
}

public final class ProcessLock {
    private let descriptor: Int32
    public init(base: URL) throws {
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        guard chmod(base.path, 0o700) == 0 else { throw Failure("cannot protect the session directory") }
        descriptor = open(base.appendingPathComponent("process.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw Failure("cannot open the session lock") }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            throw Failure("another mx command owns the session (stop watch before another command)")
        }
    }
    deinit { close(descriptor) }
}

public func jsonLine<T: Encodable>(_ value: T, write: (Data) throws -> Void = { try FileHandle.standardOutput.write(contentsOf: $0) }) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(value)
    data.append(10)
    try write(data)
}

public func resolve(_ name: String, in rooms: [RoomSummary]) throws -> RoomSummary {
    if let room = rooms.first(where: { $0.id == name }) { return room }
    let matches = rooms.filter { !$0.isHidden && $0.foldedInto == nil && $0.name == name }
    guard matches.count == 1, let room = matches.first else {
        if matches.isEmpty { throw Failure("no joined chat matches that id or exact name") }
        throw Failure("ambiguous chat name; use a room id:\n" + matches.map { "\($0.id)\t\($0.name)" }.joined(separator: "\n"))
    }
    return room
}

public struct MessageLine: Encodable {
    struct Reaction: Encodable {
        let key: String, count: Int, isMine: Bool
    }
    let type = "message"
    let roomId: String, id: String, eventId: String, sender: String, senderName: String, text: String
    let timestamp: UInt64
    let isOwn: Bool, waitingForKey: Bool, deleted: Bool, edited: Bool
    let reactions: [Reaction]
    public init(_ message: Message, roomId: String) {
        self.roomId = roomId; id = message.id; eventId = message.eventId
        sender = message.sender; senderName = message.senderName; text = message.body
        timestamp = message.timestamp; isOwn = message.isOwn; waitingForKey = message.waitingForKey
        deleted = message.isDeleted; edited = message.isEdited
        reactions = message.reactions.map { Reaction(key: $0.key, count: $0.count, isMine: $0.isMine) }
    }
}

// errors from the sdk may contain message text or server responses: audit only fixed outcomes.
struct AuditLine: Encodable {
    let operation: String, account: String, roomId: String, action: String, outcome: String
    let at: String
}
public func audit(_ operation: String, user: String, room: String, action: String, outcome: String, base: URL, io: AuditIO = AuditIO(), now: Date = Date()) throws {
    let url = base.appendingPathComponent("audit.jsonl")
    let fd = open(url.path, O_RDWR | O_APPEND | O_CREAT | O_NOFOLLOW, 0o600)
    guard fd >= 0 else { throw Failure("cannot open the audit log; write refused") }
    defer { close(fd) }
    var info = stat()
    guard fstat(fd, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else {
        throw Failure("audit log must be a regular file; write refused")
    }
    if info.st_size > 0 {
        var last: UInt8 = 0
        guard pread(fd, &last, 1, info.st_size - 1) == 1, last == 10 else {
            throw Failure("audit log has an incomplete record; preserve it and repair its final line before writing")
        }
    }
    guard fchmod(fd, 0o600) == 0 else { throw Failure("cannot protect audit log") }
    let encoder = JSONEncoder()
    var data = try encoder.encode(AuditLine(operation: operation, account: user, roomId: room, action: action,
                                            outcome: outcome, at: ISO8601DateFormatter().string(from: now)))
    data.append(10)
    try data.withUnsafeBytes { bytes in
        var offset = 0
        while offset < bytes.count {
            let written = io.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
            guard written > 0 else { throw Failure("cannot append audit log; write refused") }
            offset += written
        }
    }
    guard io.sync(fd) == 0 else { throw Failure("cannot flush audit log; write refused") }
}

// file operations are injectable at the durability boundary, not at the audit policy.
public struct AuditIO {
    var write: (Int32, UnsafeRawPointer, Int) -> Int
    var sync: (Int32) -> Int32
    public init(write: @escaping (Int32, UnsafeRawPointer, Int) -> Int = { Darwin.write($0, $1, $2) },
                sync: @escaping (Int32) -> Int32 = { fsync($0) }) {
        self.write = write
        self.sync = sync
    }
}

public func latestMessages(_ messages: [(Message, String)], limit: Int) -> [(Message, String)] {
    Array(messages.sorted { $0.0.timestamp < $1.0.timestamp }.suffix(limit))
}

public func newestFirst<T>(_ hits: [T], limit: Int, timestamp: (T) -> UInt64) -> [T] {
    Array(hits.sorted { timestamp($0) > timestamp($1) }.prefix(limit))
}

// the foreground watcher keeps one bounded snapshot, with no durable replay cursor.
public struct WatchState {
    private var seen: [String: Set<String>] = [:]
    private var previous: [String: UInt64] = [:]
    public init() {}
    public static func includes(_ room: String, selected: Set<String>?) -> Bool {
        room.hasPrefix("!") && (selected == nil || selected!.contains(room))
    }
    public mutating func seed(room: String, timestamp: UInt64, messages: [Message]) {
        previous[room] = timestamp
        seen[room] = Set(messages.map(\.eventId))
    }
    public func needsSnapshot(room: String, timestamp: UInt64) -> Bool { previous[room] != timestamp }
    public mutating func consume(room: String, timestamp: UInt64, messages: [Message], started: UInt64, limit: Int) -> [Message] {
        let emitted = messages.suffix(limit).filter {
            !$0.eventId.isEmpty && $0.timestamp >= started && !(seen[room]?.contains($0.eventId) ?? false)
        }
        seen[room] = Set(messages.map(\.eventId))
        if messages.last?.timestamp ?? 0 >= timestamp { previous[room] = timestamp }
        return emitted
    }
    public mutating func retain(live: Set<String>) {
        seen = seen.filter { live.contains($0.key) }
        previous = previous.filter { live.contains($0.key) }
    }
}

public enum WriteResult {
    case event(String), scheduled(String), receipt
}

// the durable started record must precede every server mutation.
public func performWrite(_ command: Command, user: String, room: String,
                         loadPolicy: () throws -> Data, audit: (String) throws -> Void,
                         mutate: () async throws -> WriteResult,
                         output: ([String: String]) throws -> Void) async throws {
    guard room.hasPrefix("!") else {
        throw Failure("write refused: a merged chat needs an explicit underlying room id (see chats roomIds)")
    }
    let policy: WritePolicy
    do { policy = try JSONDecoder().decode(WritePolicy.self, from: loadPolicy()) }
    catch {
        try audit("denied")
        throw Failure("write refused: create a valid private write-policy.json (see cli/README.md)")
    }
    guard policy.isWellFormed else {
        try audit("denied")
        throw Failure("write refused: create a valid private write-policy.json (see cli/README.md)")
    }
    guard policy.allows(user: user, room: room) else {
        try audit("denied")
        throw Failure("write refused: account and room id are not in write-policy.json")
    }
    if command.dryRun {
        try audit("dry-run")
        try output(["status": "dry-run", "action": command.name, "roomId": room])
        return
    }
    try audit("started")
    let result: WriteResult
    do { result = try await mutate() }
    catch {
        try? audit("failed-or-unknown")
        throw Failure("write failed or its result is unknown; inspect the chat before retrying")
    }
    do { try audit("accepted") }
    catch { throw Failure("server accepted the write but the audit log failed; do not resend; inspect the chat and repair the audit log") }
    var line = ["status": "accepted", "action": command.name, "roomId": room]
    switch result {
    case .event(let id): line["eventId"] = id
    case .receipt: break
    case .scheduled(let id): line = ["status": "scheduled", "delayId": id, "roomId": room]
    }
    do { try output(line) }
    catch { throw Failure("server accepted the write but output failed; do not resend; inspect the chat") }
}

public func visibleChats(_ rooms: [RoomSummary], limit: Int) -> [Chat] {
    rooms.filter { !$0.isHidden && $0.foldedInto == nil }.prefix(limit).map(Chat.init)
}

public func chatText(_ chat: Chat) -> String {
    let unread = chat.unread > 0 ? " (\(chat.unread))" : ""
    let last = chat.lastMessage.replacingOccurrences(of: "\n", with: " ")
    return "\(chat.network)\t\(chat.name)\(unread)\t\(last)"
}
