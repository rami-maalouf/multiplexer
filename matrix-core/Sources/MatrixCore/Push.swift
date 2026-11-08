import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// What a notification shows of one message: the notification extension asks for it with the
/// room and event ids a push carries (`MatrixPush.content`).
public struct PushContent: Equatable, Sendable {
    public var roomId: String
    public var eventId: String
    /// The name the chat list shows: the account's own name for the chat when it has one.
    public var chatName: String
    /// The sender's display name, or their id when they have none.
    public var senderName: String
    /// The message as one line, in the chat list's words: its text, or what it is ("Photo").
    public var body: String
    /// The chat's network, as `RoomSummary.network` says it.
    public var network: String
    /// A chat with one other person (the chat list's rule, `RoomSummary.isOneToOne`): the
    /// notification's title is then the sender, not the chat.
    public var isDirect: Bool
    /// The account's push rules ask for a sound.
    public var isNoisy: Bool
    /// The message mentions this account.
    public var hasMention: Bool
    /// The thread's root event, for a message in a thread; nil otherwise.
    public var threadId: String?
}

/// The notification extension's side of push: its own client, in its own process, on the app's
/// store (`matrix-core/NOTES.md`, "Push").
public enum MatrixPush {
    /// The holder names of the store's cross-process lock: the app takes it as one, the
    /// notification extension as the other, so the two never write the crypto store at once.
    public static let appLock = "app"
    public static let extensionLock = "notifications"

    /// Where a store named `store` (`StoredSession.store`) lives in the App Group's container,
    /// so the app and the notification extension open the same one.
    public static func sharedStore(in container: URL, store: String) -> URL {
        container.appendingPathComponent("matrix", isDirectory: true).appendingPathComponent(store, isDirectory: true)
    }

    /// The event `eventId` of `roomId` as a notification shows it, read with a client made as a
    /// notification extension must make one: memory-constrained (no event cache), the store's
    /// lock held as `extensionLock`, only that room loaded. `storeDirectory` is the app's store
    /// (`MatrixAccount.signIn`'s), which the extension opens while the app may run. Nil when there
    /// is nothing to show: the event is gone, was deleted, or the push rules filter it out.
    /// It waits as long as the sdk's notification client does (its default timeouts); the
    /// extension keeps its own deadline.
    /// `sessionStorage` is the app's (its Keychain item): a token refreshed here is saved there.
    public static func content(session saved: SavedSession, storeDirectory: URL, roomId: String, eventId: String,
                               sessionStorage: SessionStorage? = nil) async throws -> PushContent? {
        let client = try await MatrixAccount.builder(storeDirectory, role: .notifications, sessionStorage: sessionStorage ?? .memory(saved))
            .homeserverUrl(url: saved.homeserverUrl).build()
        try await client.restoreSessionWith(session: saved.sdkSession, roomLoadSettings: .one(roomId: roomId))
        let notifications = try await client.notificationClient(processSetup: .multipleProcesses)
        guard case .event(let item) = try await notifications.getNotification(roomId: roomId, eventId: eventId) else { return nil }
        let me = (try? client.userId()) ?? saved.userId
        let names = CustomNames.names(json: (try? await client.accountData(eventType: CustomNames.type)) ?? nil)
        return PushContent(item, roomId: roomId, eventId: eventId, ownUserId: me, customName: names[roomId],
                           kind: RoomKinds.stored(in: storeDirectory).kind(roomId))
    }
}

extension PushContent {
    /// `kind`: the bridge's word on the chat, as the app kept it (`RoomKinds`); nil when not known.
    init(_ item: NotificationItem, roomId: String, eventId: String, ownUserId: String, customName: String?, kind: BridgedKind?) {
        let room = item.roomInfo
        var sender = ""
        var body = "Message"
        switch item.event {
        case .timeline(let event):
            sender = event.senderId()
            body = (try? event.content()).map(pushBody) ?? body
        case .invite(let inviter):
            sender = inviter
            body = "Invited you"
        }
        // a bridge's bot is a service member: a bridged chat with one person has two other members.
        let service = UInt64(room.serviceMembers.count)
        let people = room.joinedMembersCount > service ? room.joinedMembersCount - service : 0
        self.init(roomId: roomId, eventId: eventId,
                  chatName: customName ?? room.displayName,
                  senderName: item.senderInfo.displayName.flatMap { $0.isEmpty ? nil : $0 } ?? sender,
                  body: body,
                  // in a bridged chat the sender is a ghost of the bridge (`@whatsapp_123:server`).
                  network: RoomNetwork.of(serviceMembers: room.serviceMembers, heroes: [sender], ownUserId: ownUserId),
                  isDirect: RoomSummary.isOneToOne(people: people, isDirect: room.isDirect, bridged: service > 0, kind: kind),
                  isNoisy: item.isNoisy ?? false, hasMention: item.hasMention ?? false, threadId: item.threadId)
    }
}

/// One line for a pushed event, in the chat list's words (`preview`).
private func pushBody(_ content: TimelineEventContent) -> String {
    guard case .messageLike(let like) = content else { return "Message" }
    switch like {
    case .roomMessage(let type, _): return preview(type)
    case .sticker: return "Sticker"
    case .poll(let question): return question
    case .roomEncrypted: return "Encrypted message"
    case .roomRedaction: return "Message deleted"
    case .callInvite, .rtcNotification: return "Call"
    default: return "Message"
    }
}

/// Where a session is kept for every process that opens its store: the sdk reads it again when
/// another process may have refreshed the access token, and saves a refreshed one.
public struct SessionStorage: Sendable {
    public var load: @Sendable () -> SavedSession?
    public var save: @Sendable (SavedSession) -> Void

    public init(load: @escaping @Sendable () -> SavedSession?, save: @escaping @Sendable (SavedSession) -> Void) {
        self.load = load
        self.save = save
    }

    /// Kept in this process only: for tests, and for a client no other process shares.
    public static func memory(_ initial: SavedSession? = nil) -> SessionStorage {
        let box = SessionBox(initial)
        return SessionStorage(load: { box.value }, save: { box.value = $0 })
    }
}

private final class SessionBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: SavedSession?
    init(_ value: SavedSession?) { stored = value }
    var value: SavedSession? {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

/// The sdk's side of `SessionStorage`.
final class SessionBridge: ClientSessionDelegate, @unchecked Sendable {
    private let storage: SessionStorage
    init(_ storage: SessionStorage) { self.storage = storage }

    func retrieveSessionFromKeychain(userId: String) throws -> Session {
        guard let saved = storage.load(), saved.userId == userId else { throw ClientError.Generic(msg: "no session for \(userId)", details: nil) }
        return saved.sdkSession
    }

    func saveSessionInKeychain(session: Session) {
        storage.save(SavedSession(userId: session.userId, deviceId: session.deviceId, homeserverUrl: session.homeserverUrl,
                                  accessToken: session.accessToken, refreshToken: session.refreshToken, oauthData: session.oauthData,
                                  nativeSlidingSync: session.slidingSyncVersion == .native))
    }
}

extension SavedSession {
    var sdkSession: Session {
        Session(accessToken: accessToken, refreshToken: refreshToken, userId: userId, deviceId: deviceId,
                homeserverUrl: homeserverUrl, oauthData: oauthData, slidingSyncVersion: nativeSlidingSync ? .native : .none)
    }
}

/// A push gateway the server sends this device's notifications to (an http pusher).
public struct Pusher: Equatable, Sendable {
    /// The gateway's name for the app and its push service (`com.example.app.ios.dev`).
    public var appId: String
    /// The device's address at the push service: an APNs token in base64.
    public var pushkey: String
    /// The gateway's notify endpoint (`https://<gateway>/_matrix/push/v1/notify`).
    public var url: String
    public var appDisplayName: String
    public var deviceDisplayName: String
    /// What the gateway sends as it is, beside the room and event ids (JSON).
    public var defaultPayload: String
    /// The gateway sends only the room and event ids: the extension reads the message itself.
    public var eventIdOnly: Bool
    public var lang: String

    public init(appId: String, pushkey: String, url: String, appDisplayName: String, deviceDisplayName: String,
                defaultPayload: String = Pusher.apnsPayload, eventIdOnly: Bool = true, lang: String = "en") {
        self.appId = appId
        self.pushkey = pushkey
        self.url = url
        self.appDisplayName = appDisplayName
        self.deviceDisplayName = deviceDisplayName
        self.defaultPayload = defaultPayload
        self.eventIdOnly = eventIdOnly
        self.lang = lang
    }

    /// An APNs device token as a pusher's pushkey (what Sygnal expects).
    public static func pushkey(apnsToken: Data) -> String { apnsToken.base64EncodedString() }

    /// The alert every push carries: `mutable-content` wakes the notification extension, which
    /// writes the chat, the sender and the text; when it cannot, "New message" shows.
    public static let apnsPayload = #"{"aps":{"alert":{"body":"New message"},"mutable-content":1}}"#
}

extension MatrixAccount {
    /// Asks the server to send this account's notifications to `pusher`'s gateway. A pusher with
    /// the same app id and pushkey on another account is removed (`append: false`).
    public func setPusher(_ pusher: Pusher) async throws {
        try await client.setPusher(
            identifiers: PusherIdentifiers(pushkey: pusher.pushkey, appId: pusher.appId),
            kind: .http(data: HttpPusherData(url: pusher.url, format: pusher.eventIdOnly ? .eventIdOnly : nil,
                                             defaultPayload: pusher.defaultPayload)),
            appDisplayName: pusher.appDisplayName, deviceDisplayName: pusher.deviceDisplayName,
            profileTag: nil, lang: pusher.lang, append: false)
    }

    /// Stops the server sending to the pusher with this app id and pushkey. One the server does
    /// not have is no error.
    public func deletePusher(appId: String, pushkey: String) async throws {
        try await client.deletePusher(identifiers: PusherIdentifiers(pushkey: pushkey, appId: appId))
    }

    /// The account's http pushers, as the server has them (`GET /_matrix/client/v3/pushers`).
    public func pushers() async throws -> [Pusher] {
        let session = try savedSession()
        guard let base = URL(string: session.homeserverUrl) else { throw URLError(.badURL) }
        var request = URLRequest(url: base.appendingPathComponent("_matrix/client/v3/pushers"), timeoutInterval: 20)
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let list = (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["pushers"] as? [[String: Any]] ?? []
        return list.compactMap { entry in
            guard entry["kind"] as? String == "http", let appId = entry["app_id"] as? String,
                  let pushkey = entry["pushkey"] as? String, let info = entry["data"] as? [String: Any] else { return nil }
            let payload = (info["default_payload"]).flatMap { try? JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys]) }
            return Pusher(appId: appId, pushkey: pushkey, url: info["url"] as? String ?? "",
                          appDisplayName: entry["app_display_name"] as? String ?? "",
                          deviceDisplayName: entry["device_display_name"] as? String ?? "",
                          defaultPayload: payload.map { String(decoding: $0, as: UTF8.self) } ?? "",
                          eventIdOnly: info["format"] as? String == "event_id_only", lang: entry["lang"] as? String ?? "")
        }
    }
}
