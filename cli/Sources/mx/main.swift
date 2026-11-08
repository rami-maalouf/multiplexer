import Foundation
import MatrixCore
import CLIKit
import Darwin

// report broken output after server acceptance instead of silently dying with sigpipe.
signal(SIGPIPE, SIG_IGN)

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

func chats(_ command: Command) async throws {
    let json = command.flags.contains("--json")
    let limit = command.options["--limit"].flatMap(Int.init) ?? Int.max
    let (account, _) = try await signedIn()
    // a new device's first sync is slow (the sdk's start is cpu-bound): the tests allow 120 s.
    let rooms = try await account.rooms(timeout: 120)
    // a deleted chat, or one folded into a merged chat, shows in no list.
    let shown = visibleChats(rooms, limit: limit)
    if json {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        print(String(decoding: try encoder.encode(Array(shown)), as: UTF8.self))
    } else {
        for chat in shown {
            print(chatText(chat))
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

func read(_ command: Command) async throws {
    let (account, _) = try await signedIn()
    let room = try resolve(command.positionals[0], in: await account.rooms(timeout: 120))
    var messages: [(Message, String)] = []
    for id in await account.roomsOf(room.id) {
        messages += try await account.messages(roomId: id, limit: command.limit, timeout: 120).map { ($0, id) }
    }
    for (message, id) in latestMessages(messages, limit: command.limit) {
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
    for hit in newestFirst(results.messages + results.links, limit: command.limit, timestamp: { $0.timestamp }) {
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
    var state = WatchState()
    for room in initial where WatchState.includes(room.id, selected: selectedRooms) {
        let messages = try await account.messages(roomId: room.id, limit: command.limit, timeout: 120)
        state.seed(room: room.id, timestamp: room.lastTimestamp, messages: messages)
        account.closeMessages(roomId: room.id)
    }
    let started = UInt64(Date().timeIntervalSince1970 * 1000)
    try jsonLine(["type": "ready", "scope": "new messages after startup; best effort, no durable cursor"])
    while true {
        try await Task.sleep(nanoseconds: 500_000_000)
        let rooms = try await account.rooms(timeout: 120)
        for room in rooms where WatchState.includes(room.id, selected: selectedRooms) {
            guard state.needsSnapshot(room: room.id, timestamp: room.lastTimestamp) else { continue }
            let messages = try await account.messages(roomId: room.id, limit: command.limit, timeout: 120)
            account.closeMessages(roomId: room.id)
            for message in state.consume(room: room.id, timestamp: room.lastTimestamp, messages: messages,
                                         started: started, limit: command.limit) {
                try jsonLine(MessageLine(message, roomId: room.id))
            }
        }
        let live = Set(rooms.map(\.id))
        state.retain(live: live)
    }
}

func recover() async throws {
    guard let key = readLine(), !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Failure("no recovery key on stdin") }
    let (account, _) = try await signedIn()
    do { try await account.recover(recoveryKey: key) }
    catch { throw Failure("recovery failed; check the key and server connection") }
    try jsonLine(["status": "recovered"])
}

func writeCommand(_ command: Command) async throws {
    let (account, _) = try await signedIn()
    let room = try resolve(command.positionals[0], in: await account.rooms(timeout: 120))
    let user = try account.userId
    let operation = UUID().uuidString
    try await performWrite(command, user: user, room: room.id, loadPolicy: {
        try Data(contentsOf: Place.base.appendingPathComponent("write-policy.json"))
    }, audit: { outcome in
        try audit(operation, user: user, room: room.id, action: command.name, outcome: outcome, base: Place.base)
    }, mutate: {
        switch command.name {
        case "send": return .event(try await account.sendTextConfirmed(roomId: room.id, text: command.positionals[1]))
        case "react": return .event(try await account.addReactionConfirmed(roomId: room.id, eventId: command.positionals[1], key: command.positionals[2]))
        case "mark-read": try await account.markRead(roomId: room.id, timeout: 120); return .receipt
        case "later": return .scheduled(try await account.sendLater(roomId: room.id, text: command.positionals[1], at: command.date!, timeout: 120))
        default: throw Failure("unsupported write")
        }
    }, output: { try jsonLine($0) })
}

let args = Array(CommandLine.arguments.dropFirst())
do {
    let command = try Command(args)
    if ["help", "-h", "--help"].contains(command.name) { print(usage); exit(0) }
    let sessionLock = try ProcessLock(base: Place.base)
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
