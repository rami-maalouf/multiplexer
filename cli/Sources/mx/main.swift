import Foundation
import MatrixCore

// mx: read and act on the chat app's Matrix account from a terminal.
// c0 (the spike): login, whoami, chats, logout. one process per command; a background
// process that keeps the sync running comes in c1.

let usage = """
usage:
  mx login <@user:server> --password-stdin   sign in as a new device; the password comes on stdin
  mx whoami                                   the signed-in account and device
  mx chats [--json] [--limit <n>]             the chats, most recent first
  mx logout                                   sign out on the server and forget the session here
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

func chats(_ args: [String]) async throws {
    let json = args.contains("--json")
    var limit = Int.max
    if let i = args.firstIndex(of: "--limit") {
        guard i + 1 < args.count, let n = Int(args[i + 1]), n > 0 else { throw Failure("--limit needs a positive number") }
        limit = n
    }
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

let args = Array(CommandLine.arguments.dropFirst())
do {
    switch args.first {
    case "login": try await login(Array(args.dropFirst()))
    case "whoami": try await whoami()
    case "chats": try await chats(Array(args.dropFirst()))
    case "logout": try await logout()
    case "-h", "--help", "help", nil: print(usage)
    default: throw Failure(usage)
    }
    // the sdk's background tasks would keep the process alive.
    exit(0)
} catch {
    FileHandle.standardError.write(Data("mx: \(error)\n".utf8))
    exit(1)
}
