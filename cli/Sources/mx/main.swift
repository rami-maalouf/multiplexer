import Foundation
import MatrixCore
import CLIKit
import Darwin

// mx: read and act on the chat app's Matrix account from a terminal.

let usage = """
usage:
  mx login <@user:server> --password-stdin
  mx whoami
  mx chats [--json] [--limit <1..1000>]
  mx read <chat> [--limit <1..1000>]
  mx search <text> [--chat <chat>] [--limit <1..1000>]
  mx watch [--chat <chat>] [--limit <1..1000>]
  mx recover --key-stdin
  mx send <chat> <text> [--dry-run]
  mx react <chat> <$event-id> <reaction> [--dry-run]
  mx mark-read <chat> [--dry-run]
  mx later <chat> <text> --at <ISO8601-with-timezone> [--dry-run]
  mx logout
chat: exact room id or exact name; duplicate names are an error.
writes require write-policy.json in mx's application support folder.
read/search/watch emit JSON lines; watch is a foreground, best-effort stream.
"""

/// where mx keeps the session (the Keychain) and the sdk's store (application support).
/// both are this program's own: the app's session is never read or changed.
enum Place {
    static let keychain = SessionKeychain(service: "com.ramimaalouf.multiplexer.cli.session")
    static let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("com.ramimaalouf.multiplexer.cli", isDirectory: true)

    static func store(_ name: String) -> URL {
        base.appendingPathComponent("matrix", isDirectory: true).appendingPathComponent(name, isDirectory: true)
    }
}

struct Failure: Error, CustomStringConvertible {
    var description: String
    init(_ description: String) { self.description = description }
}

/// the session as the sdk keeps it: a refreshed token replaces the one in the Keychain item.
let sessionStorage = SessionStorage(load: { try? Place.keychain.read()?.session }, save: { session in
    guard var stored = try? Place.keychain.read() else { return }
    stored.session = session
    try? Place.keychain.write(stored)
})

func signedIn() async throws -> (MatrixAccount, StoredSession) {
    guard let stored = try Place.keychain.read() else { throw Failure("signed out: run `mx login` first") }
    let directory = Place.store(stored.store)
    guard FileManager.default.fileExists(atPath: directory.path) else {
        throw Failure("the store \(directory.path) is gone, so this device lost its keys: run `mx logout`, then `mx login`")
    }
    let account = try await MatrixAccount.restore(stored.session, storeDirectory: directory, searchIndexKey: stored.searchKey,
                                                  sessionStorage: sessionStorage)
    return (account, stored)
}

func login(_ args: [String]) async throws {
    guard let user = args.first, user.hasPrefix("@"), let server = user.split(separator: ":", maxSplits: 1).last,
          user.contains(":") else { throw Failure(usage) }
    // a password in argv shows in `ps` and in shell history: stdin only.
    guard args.contains("--password-stdin") else { throw Failure("the password comes on stdin: add --password-stdin") }
    guard try Place.keychain.read() == nil else { throw Failure("already signed in: run `mx logout` first") }
    let password = (readLine(strippingNewline: true) ?? "")
    guard !password.isEmpty else { throw Failure("no password on stdin") }

    let store = UUID().uuidString, searchKey = SearchIndex.newKey()
    let directory = Place.store(store)
    do {
        let account = try await MatrixAccount.signIn(homeserver: String(server), user: user, password: password,
                                                     deviceName: "Mux CLI", storeDirectory: directory,
                                                     searchIndexKey: searchKey, sessionStorage: sessionStorage)
        do {
            try Place.keychain.write(StoredSession(session: try account.savedSession(), store: store, searchKey: searchKey,
                                                   storeLocation: .data))
        } catch {
            // a session this device cannot keep must not stay on the server.
            try? await account.signOut()
            throw error
        }
        let saved = try account.savedSession()
        print("signed in as \(saved.userId), device \(saved.deviceId)")
    } catch {
        try? FileManager.default.removeItem(at: directory)
        throw error
    }
}

func whoami() async throws {
    guard let stored = try Place.keychain.read() else { throw Failure("signed out") }
    print("\(stored.session.userId), device \(stored.session.deviceId), \(stored.session.homeserverUrl)")
    print("sdk \(MatrixCore.sdkCommit())")
}

/// one chat as mx prints it: plain fields, stable names, for agents to parse.
struct Chat: Encodable {
    var id: String
    var roomIds: [String]
    var name: String
    var network: String
    var isDirect: Bool
    var unread: Int
    var mentions: Int
    var markedUnread: Bool
    var muted: Bool
    var archived: Bool
    var pinned: Bool
    var lastMessage: String
    var lastSender: String
    var lastIsOwn: Bool
    /// milliseconds since 1970; 0 when the chat has no message.
    var lastTimestamp: UInt64

    init(_ room: RoomSummary) {
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

func chats(_ command: Command) async throws {
    let json = command.flags.contains("--json")
    let limit = command.options["--limit"].flatMap(Int.init) ?? Int.max
    let (account, _) = try await signedIn()
    // a new device's first sync is slow (the sdk's start is cpu-bound): the tests allow 120 s.
    let rooms = try await account.rooms(timeout: 120)
    // a deleted chat, or one folded into a merged chat, shows in no list.
    let shown = rooms.filter { !$0.isHidden && $0.foldedInto == nil }.prefix(limit).map(Chat.init)
    if json {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        print(String(decoding: try encoder.encode(Array(shown)), as: UTF8.self))
    } else {
        for chat in shown {
            let unread = chat.unread > 0 ? " (\(chat.unread))" : ""
            let last = chat.lastMessage.replacingOccurrences(of: "\n", with: " ")
            print("\(chat.network)\t\(chat.name)\(unread)\t\(last)")
        }
    }
}

func logout() async throws {
    guard let stored = try Place.keychain.read() else { print("already signed out"); return }
    let directory = Place.store(stored.store)
    if FileManager.default.fileExists(atPath: directory.path) {
        let (account, _) = try await signedIn()
        try await account.signOut()
    } else {
        // no store: sign the session out through a scratch store.
        guard await MatrixAccount.signOutOnServer(stored.session, scratchDirectory: Place.store("scratch-" + UUID().uuidString)) else {
            throw Failure("the server could not be reached: the session is kept, try again")
        }
    }
    try? FileManager.default.removeItem(at: directory)
    try Place.keychain.delete()
    print("signed out \(stored.session.userId), device \(stored.session.deviceId)")
}

final class ProcessLock {
    private let descriptor: Int32
    init() throws {
        try FileManager.default.createDirectory(at: Place.base, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        guard chmod(Place.base.path, 0o700) == 0 else { throw Failure("cannot protect the session directory") }
        descriptor = open(Place.base.appendingPathComponent("process.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw Failure("cannot open the session lock") }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            throw Failure("another mx command owns the session (stop watch before another command)")
        }
    }
    deinit { close(descriptor) }
}

func jsonLine<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(value)
    data.append(10)
    try FileHandle.standardOutput.write(contentsOf: data)
}

func resolve(_ name: String, in rooms: [RoomSummary]) throws -> RoomSummary {
    if let room = rooms.first(where: { $0.id == name }) { return room }
    let matches = rooms.filter { !$0.isHidden && $0.foldedInto == nil && $0.name == name }
    guard matches.count == 1, let room = matches.first else {
        if matches.isEmpty { throw Failure("no joined chat matches that id or exact name") }
        throw Failure("ambiguous chat name; use a room id:\n" + matches.map { "\($0.id)\t\($0.name)" }.joined(separator: "\n"))
    }
    return room
}

struct MessageLine: Encodable {
    struct Reaction: Encodable {
        let key: String, count: Int, isMine: Bool
    }
    let type = "message"
    let roomId: String, id: String, eventId: String, sender: String, senderName: String, text: String
    let timestamp: UInt64
    let isOwn: Bool, waitingForKey: Bool, deleted: Bool, edited: Bool
    let reactions: [Reaction]
    init(_ message: Message, roomId: String) {
        self.roomId = roomId; id = message.id; eventId = message.eventId
        sender = message.sender; senderName = message.senderName; text = message.body
        timestamp = message.timestamp; isOwn = message.isOwn; waitingForKey = message.waitingForKey
        deleted = message.isDeleted; edited = message.isEdited
        reactions = message.reactions.map { Reaction(key: $0.key, count: $0.count, isMine: $0.isMine) }
    }
}

func read(_ command: Command) async throws {
    let (account, _) = try await signedIn()
    let room = try resolve(command.positionals[0], in: await account.rooms(timeout: 120))
    var messages: [(Message, String)] = []
    for id in await account.roomsOf(room.id) {
        messages += try await account.messages(roomId: id, limit: command.limit, timeout: 120).map { ($0, id) }
    }
    for (message, id) in messages.sorted(by: { $0.0.timestamp < $1.0.timestamp }).suffix(command.limit) {
        try jsonLine(MessageLine(message, roomId: id))
    }
}

func search(_ command: Command) async throws {
    let (account, _) = try await signedIn()
    let rooms = try await account.rooms(timeout: 120)
    let room = try command.options["--chat"].map { try resolve($0, in: rooms).id }
    let searchRooms: [String]
    if let room, room.hasPrefix("merge:") { searchRooms = await account.roomsOf(room) }
    else { searchRooms = [] }
    var results = try await account.search(command.positionals[0], in: searchRooms.first ?? room,
                                           limit: command.limit, timeout: 120)
    for id in searchRooms.dropFirst() {
        let part = try await account.search(command.positionals[0], in: id, limit: command.limit, timeout: 120)
        results.messages += part.messages; results.links += part.links
    }
    for chat in results.chats.prefix(command.limit) { try jsonLine(["type": "chat", "roomId": chat.id, "name": chat.name]) }
    struct Hit: Encodable {
        let type = "search-message"
        let roomId: String, eventId: String, sender: String, senderName: String, text: String
        let timestamp: UInt64
    }
    for hit in (results.messages + results.links).sorted(by: { $0.timestamp > $1.timestamp }).prefix(command.limit) {
        try jsonLine(Hit(roomId: hit.chat.id, eventId: hit.eventId, sender: hit.sender, senderName: hit.senderName,
                         text: hit.body, timestamp: hit.timestamp))
    }
    let status = await account.searchIndexStatus()
    struct Status: Encodable {
        let type = "search-status"
        let scope: String
        let backfillDone: Bool
    }
    let pages = room == nil ? 3 : 30
    try jsonLine(Status(scope: "local-index; synced messages and backfill up to 3 months; scan capped at \(pages) pages of 20 index hits per query; results may be truncated even when backfillDone is true; not exhaustive history", backfillDone: status.backfillDone))
}

func watch(_ command: Command) async throws {
    let (account, _) = try await signedIn()
    let initial = try await account.rooms(timeout: 120)
    let selected = try command.options["--chat"].map { try resolve($0, in: initial).id }
    let selectedRooms: Set<String>?
    if let selected { selectedRooms = Set(await account.roomsOf(selected)) } else { selectedRooms = nil }
    // snapshots are bounded; timestamps avoid replaying cached history after dedupe eviction.
    var seen: [String: Set<String>] = [:]
    var previous: [String: UInt64] = [:]
    for room in initial where room.id.hasPrefix("!") && (selectedRooms == nil || selectedRooms!.contains(room.id)) {
        previous[room.id] = room.lastTimestamp
        let messages = try await account.messages(roomId: room.id, limit: command.limit, timeout: 120)
        seen[room.id] = Set(messages.map(\.eventId))
        account.closeMessages(roomId: room.id)
    }
    let started = UInt64(Date().timeIntervalSince1970 * 1000)
    try jsonLine(["type": "ready", "scope": "new messages after startup; best effort, no durable cursor"])
    while true {
        try await Task.sleep(nanoseconds: 500_000_000)
        let rooms = try await account.rooms(timeout: 120)
        for room in rooms where room.id.hasPrefix("!") && (selectedRooms == nil || selectedRooms!.contains(room.id)) {
            guard previous[room.id] != room.lastTimestamp else { continue }
            let messages = try await account.messages(roomId: room.id, limit: command.limit, timeout: 120)
            account.closeMessages(roomId: room.id)
            let ids = Set(messages.map(\.eventId))
            for message in messages.suffix(command.limit) where !message.eventId.isEmpty && message.timestamp >= started
                && !(seen[room.id]?.contains(message.eventId) ?? false) {
                try jsonLine(MessageLine(message, roomId: room.id))
            }
            seen[room.id] = ids
            if messages.last?.timestamp ?? 0 >= room.lastTimestamp { previous[room.id] = room.lastTimestamp }
        }
        let live = Set(rooms.map(\.id))
        seen = seen.filter { live.contains($0.key) }
        previous = previous.filter { live.contains($0.key) }
    }
}

func recover() async throws {
    guard let key = readLine(), !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Failure("no recovery key on stdin") }
    let (account, _) = try await signedIn()
    do { try await account.recover(recoveryKey: key) }
    catch { throw Failure("recovery failed; check the key and server connection") }
    try jsonLine(["status": "recovered"])
}

// errors from the sdk may contain message text or server responses: audit only fixed outcomes.
struct AuditLine: Encodable {
    let operation: String, account: String, roomId: String, action: String, outcome: String
    let at: String
}
func audit(_ operation: String, user: String, room: String, action: String, outcome: String) throws {
    let url = Place.base.appendingPathComponent("audit.jsonl")
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
                                            outcome: outcome, at: ISO8601DateFormatter().string(from: Date())))
    data.append(10)
    try data.withUnsafeBytes { bytes in
        var offset = 0
        while offset < bytes.count {
            let written = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
            guard written > 0 else { throw Failure("cannot append audit log; write refused") }
            offset += written
        }
    }
    guard fsync(fd) == 0 else { throw Failure("cannot flush audit log; write refused") }
}

func writeCommand(_ command: Command) async throws {
    let (account, _) = try await signedIn()
    let room = try resolve(command.positionals[0], in: await account.rooms(timeout: 120))
    guard room.id.hasPrefix("!") else { throw Failure("write refused: a merged chat needs an explicit underlying room id (see chats roomIds)") }
    let user = try account.userId
    let operation = UUID().uuidString
    let policyURL = Place.base.appendingPathComponent("write-policy.json")
    let policy: WritePolicy
    do { policy = try JSONDecoder().decode(WritePolicy.self, from: Data(contentsOf: policyURL)) }
    catch {
        try audit(operation, user: user, room: room.id, action: command.name, outcome: "denied")
        throw Failure("write refused: create a valid private write-policy.json (see cli/README.md)")
    }
    guard policy.allows(user: user, room: room.id) else {
        try audit(operation, user: user, room: room.id, action: command.name, outcome: "denied")
        throw Failure("write refused: account and room id are not in write-policy.json")
    }
    if command.dryRun {
        try audit(operation, user: user, room: room.id, action: command.name, outcome: "dry-run")
        try jsonLine(["status": "dry-run", "action": command.name, "roomId": room.id]); return
    }
    try audit(operation, user: user, room: room.id, action: command.name, outcome: "started")
    var eventId: String?
    var delayId: String?
    do {
        switch command.name {
        case "send": eventId = try await account.sendTextConfirmed(roomId: room.id, text: command.positionals[1])
        case "react":
            eventId = try await account.addReactionConfirmed(roomId: room.id, eventId: command.positionals[1], key: command.positionals[2])
        case "mark-read": try await account.markRead(roomId: room.id, timeout: 120)
        case "later":
            delayId = try await account.sendLater(roomId: room.id, text: command.positionals[1], at: command.date!, timeout: 120)
        default: throw Failure("unsupported write")
        }
    } catch {
        try? audit(operation, user: user, room: room.id, action: command.name, outcome: "failed-or-unknown")
        throw Failure("write failed or its result is unknown; inspect the chat before retrying")
    }
    do { try audit(operation, user: user, room: room.id, action: command.name, outcome: "accepted") }
    catch { throw Failure("server accepted the write but the audit log failed; do not resend; inspect the chat and repair the audit log") }
    if let delayId {
        try jsonLine(["status": "scheduled", "delayId": delayId, "roomId": room.id])
    } else {
        var result = ["status": "accepted", "action": command.name, "roomId": room.id]
        if let eventId { result["eventId"] = eventId }
        try jsonLine(result)
    }
}

let args = Array(CommandLine.arguments.dropFirst())
do {
    let command = try Command(args)
    if ["help", "-h", "--help"].contains(command.name) { print(usage); exit(0) }
    let sessionLock = try ProcessLock()
    switch command.name {
    case "login": try await login(command.positionals + ["--password-stdin"])
    case "whoami": try await whoami()
    case "chats": try await chats(command)
    case "read": try await read(command)
    case "search": try await search(command)
    case "watch": try await watch(command)
    case "recover": try await recover()
    case "send", "react", "mark-read", "later": try await writeCommand(command)
    case "logout": try await logout()
    default: throw Failure(usage)
    }
    withExtendedLifetime(sessionLock) {}
    exit(0)
} catch {
    // keep arbitrary sdk diagnostics (which may contain user content) out of agent logs.
    let text = (error as? UsageError)?.description ?? (error as? Failure)?.description ?? "operation failed; check the server connection and session"
    FileHandle.standardError.write(Data("mx: \(text)\n".utf8))
    exit(1)
}
