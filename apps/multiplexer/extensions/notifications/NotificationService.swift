import Foundation
import UserNotifications

/// The notification service extension. A push from our gateway carries only a room and an event
/// id (`event_id_only`), with "New message" as its alert; this reads the message with MatrixCore
/// (compiled into this extension with the sdk, as in the app) and shows the chat, the sender and
/// the text. When it cannot (no session, the store not shared, the phone not unlocked since it
/// started, an error, the time running out), "New message" shows: never an empty or raw payload.
///
/// `scripts/add-notification-extension.sh` builds it into the app's `PlugIns/`, with its Info.plist
/// naming the App Group (`MultiplexerAppGroup`), the app's Keychain group
/// (`MultiplexerKeychainGroup`) and the session's Keychain service (`MultiplexerSessionService`).
@objc(NotificationService)
final class NotificationService: UNNotificationServiceExtension {
    private let lock = NSLock()
    private var handler: ((UNNotificationContent) -> Void)?
    private var fallback: UNNotificationContent?
    private var work: Task<Void, Never>?
    private let started = Date()

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        let content = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        let info = request.content.userInfo
        if content.body.isEmpty { content.body = "New message" }
        // the gateway sends the server's count of unread chats with each push.
        if let count = (info["unread_count"] as? NSNumber)?.intValue { content.badge = NSNumber(value: count) }
        let roomId = info["room_id"] as? String ?? "", eventId = info["event_id"] as? String ?? ""
        // one chat's notifications group together.
        if !roomId.isEmpty { content.threadIdentifier = roomId }
        lock.withLock {
            handler = contentHandler
            fallback = content.copy() as? UNNotificationContent
        }
        guard !roomId.isEmpty, !eventId.isEmpty else {
            finish(content, outcome: "no room or event id")
            return
        }
        work = Task {
            do {
                guard let shown = try await Self.read(roomId: roomId, eventId: eventId) else {
                    finish(content, outcome: "nothing to show")
                    return
                }
                Self.fill(content, with: shown)
                finish(content, outcome: "shown")
            } catch {
                finish(content, outcome: "failed: \(Self.describe(error))")
            }
        }
    }

    override func serviceExtensionTimeWillExpire() {
        work?.cancel()
        if let fallback = lock.withLock({ fallback }) { finish(fallback, outcome: "out of time") }
    }

    /// Hands the content to the system once, and logs the push's outcome in the App Group.
    private func finish(_ content: UNNotificationContent, outcome: String) {
        guard let handler = lock.withLock({ () -> ((UNNotificationContent) -> Void)? in
            defer { self.handler = nil }
            return self.handler
        }) else { return }
        handler(content)
        Self.log("\(outcome) in \(Int(Date().timeIntervalSince(started) * 1000)) ms, peak \(Self.memoryMB()) MB")
    }

    /// The session from the app's Keychain item, the store from the App Group, then the message.
    private static func read(roomId: String, eventId: String) async throws -> PushContent? {
        let bundle = Bundle.main
        guard let group = bundle.object(forInfoDictionaryKey: "MultiplexerAppGroup") as? String,
              let keychainGroup = bundle.object(forInfoDictionaryKey: "MultiplexerKeychainGroup") as? String,
              let service = bundle.object(forInfoDictionaryKey: "MultiplexerSessionService") as? String else {
            throw ExtensionProblem.notConfigured
        }
        // the item is readable after the phone's first unlock; before, this throws.
        let keychain = SessionKeychain(service: service, accessGroup: keychainGroup)
        guard let stored = try keychain.read() else { throw ExtensionProblem.signedOut }
        // the app publishes this only after the complete store has moved successfully.
        guard stored.storeLocation == .group else { throw ExtensionProblem.storeNotShared }
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
            throw ExtensionProblem.noAppGroup
        }
        let store = MatrixPush.sharedStore(in: container, store: stored.store)
        guard FileManager.default.fileExists(atPath: store.path) else { throw ExtensionProblem.storeNotShared }
        // a token refreshed here goes back into the app's item.
        let storage = SessionStorage(load: { try? keychain.read()?.session }, save: { session in
            guard var current = try? keychain.read() else { return }
            current.session = session
            try? keychain.write(current)
        })
        return try await MatrixPush.content(session: stored.session, storeDirectory: store, roomId: roomId, eventId: eventId,
                                            sessionStorage: storage)
    }

    /// A chat with one person shows that person as the title; a group shows its name, and the
    /// sender under it.
    private static func fill(_ content: UNMutableNotificationContent, with shown: PushContent) {
        if shown.isDirect {
            content.title = shown.senderName
        } else {
            content.title = shown.chatName
            content.subtitle = shown.senderName
        }
        content.body = shown.body
        content.threadIdentifier = shown.roomId
        if shown.isNoisy { content.sound = .default }
        content.userInfo["network"] = shown.network
    }

    /// One line per push in `<App Group>/notifications.log`: never a message, a name or an id.
    private static func log(_ line: String) {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "MultiplexerAppGroup") as? String,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { return }
        let file = container.appendingPathComponent("notifications.log")
        let stamp = ISO8601DateFormatter().string(from: Date())
        let data = Data("\(stamp) \(line)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: file) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: file)
        }
    }

    /// The process's peak memory footprint, in MB (what iOS's extension limit counts).
    private static func memoryMB() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        return result == KERN_SUCCESS ? Int(info.ledger_phys_footprint_peak / 1_048_576) : -1
    }

    /// The error's kind for the log, without its text (which can carry an id).
    private static func describe(_ error: Error) -> String {
        if let problem = error as? ExtensionProblem { return "\(problem)" }
        if case MatrixCoreError.keychain(let status) = error { return "keychain \(status)" }
        return String(describing: type(of: error))
    }
}

private enum ExtensionProblem: Error {
    case notConfigured, signedOut, noAppGroup, storeNotShared
}
