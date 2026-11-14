import { expect, test } from 'bun:test';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

test('the actual service keeps account-scoped destinations on timeout and unavailable-store fallbacks', () => {
  const directory = mkdtempSync(join(tmpdir(), 'mux-notification-service-'));
  const root = resolve(import.meta.dir, '..');
  const source = 'apps/multiplexer/extensions/notifications/NotificationService.swift';
  try {
    const app = join(directory, 'Fixture.app/Contents');
    mkdirSync(join(app, 'MacOS'), { recursive: true });
    writeFileSync(join(app, 'Info.plist'), `<?xml version="1.0"?><plist version="1.0"><dict>
      <key>CFBundleIdentifier</key><string>org.example.notification-fixture</string>
      <key>CFBundleExecutable</key><string>check</string>
      <key>MultiplexerAppGroup</key><string>group.org.example.notification-fixture</string>
      <key>MultiplexerKeychainGroup</key><string>fixture</string>
      <key>MultiplexerSessionService</key><string>fixture</string>
    </dict></plist>`);
    writeFileSync(join(directory, 'NotificationService.swift'), process.env.MUX_NOTIFICATION_BASELINE
      ? Bun.spawnSync(['git', 'show', `${process.env.MUX_NOTIFICATION_BASELINE}:${source}`], { cwd: root }).stdout.toString()
      : readFileSync(join(root, source), 'utf8'));
    writeFileSync(join(directory, 'Fixture.swift'), String.raw`
import Foundation
import UserNotifications
struct SavedSession { var userId = "@test1:example.org"; var deviceId = "device" }
enum StoreLocation { case group, local }
struct StoredSession { var session = SavedSession(); var store = "store"; var storeLocation = StoreLocation.local }
struct SessionKeychain {
    static var stored: StoredSession? = StoredSession()
    init(service: String, accessGroup: String) {}
    func read() throws -> StoredSession? { Self.stored }
    func write(_ value: StoredSession) throws {}
}
struct SessionStorage {
    init(load: @escaping () -> SavedSession?, save: @escaping (SavedSession) -> Void) {}
}
enum MatrixCoreError: Error { case keychain(Int32) }
struct PushContent {
    var isDirect = true; var senderName = "Sender"; var chatName = "Chat"; var body = "Text"
    var roomId = "!room:example.org"; var isNoisy = true; var network = "matrix"; var senderAvatarUrl: String? = nil
}
enum MatrixPush {
    static func sharedStore(in container: URL, store: String) -> URL { container.appendingPathComponent(store) }
    static func content(session: SavedSession, storeDirectory: URL, roomId: String, eventId: String,
                        sessionStorage: SessionStorage) async throws -> PushContent? { nil }
    static func senderAvatar(session: SavedSession, url: String?) async -> Data? { nil }
}
enum CommunicationNotification {
    static func content(_ content: UNNotificationContent, shown: PushContent, avatar: Data?) async -> UNNotificationContent { content }
}
final class Delivery {
    let lock = NSLock(); private var contents: [UNNotificationContent] = []
    func append(_ content: UNNotificationContent) { lock.withLock { contents.append(content) } }
    var values: [UNNotificationContent] { lock.withLock { contents } }
}
@main struct Check {
    static func main() async throws {
        for expired in [true, false] {
            SessionKeychain.stored = StoredSession()
            let service = NotificationService(), delivery = Delivery(), content = UNMutableNotificationContent()
            content.userInfo = ["room_id": "!room:example.org", "event_id": "$event", "unread_count": 3]
            service.didReceive(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil),
                               withContentHandler: delivery.append)
            if expired { service.serviceExtensionTimeWillExpire() }
            for _ in 0..<100 where delivery.values.isEmpty { try await Task.sleep(nanoseconds: 10_000_000) }
            precondition(delivery.values.count == 1)
            let shown = delivery.values[0]
            precondition(shown.body == "New message" && shown.badge == 3)
            precondition(shown.threadIdentifier == "!room:example.org")
            guard let entry = shown.userInfo["exact"] as? [String: String], let encoded = entry["args"] else {
                preconditionFailure("fallback lost the chat destination")
            }
            let args = try JSONSerialization.jsonObject(with: Data(encoded.utf8)) as! [Any]
            precondition(args[0] as? String == "chat:@test1:example.org:!room:example.org")
            service.serviceExtensionTimeWillExpire()
            try await Task.sleep(nanoseconds: 50_000_000)
            precondition(delivery.values.count == 1, "expiration delivered twice")
        }
        SessionKeychain.stored = nil
        let service = NotificationService(), delivery = Delivery(), content = UNMutableNotificationContent()
        content.userInfo = ["room_id": "!room:example.org", "event_id": "$event", "exact": ["navigate": "/unsafe"], "navigate": "/unsafe"]
        service.didReceive(UNNotificationRequest(identifier: "signed-out", content: content, trigger: nil), withContentHandler: delivery.append)
        service.serviceExtensionTimeWillExpire()
        precondition(delivery.values.count == 1)
        precondition(delivery.values[0].userInfo["exact"] == nil && delivery.values[0].userInfo["navigate"] == nil)
        print("service fallback activation passed")
    }
}
`);
    const binary = join(app, 'MacOS/check');
    const compile = Bun.spawnSync(['xcrun', 'swiftc', '-parse-as-library', '-swift-version', '5',
      join(directory, 'NotificationService.swift'), join(directory, 'Fixture.swift'),
      join(root, 'apps/multiplexer/extensions/notifications/NotificationActivation.swift'), '-o', binary]);
    if (compile.exitCode !== 0) throw new Error(compile.stderr.toString());
    const run = Bun.spawnSync([binary]);
    if (run.exitCode !== 0) throw new Error(run.stderr.toString().split('\n').slice(0, 4).join('\n'));
    expect(run.stdout.toString()).toContain('service fallback activation passed');
  } finally { rmSync(directory, { recursive: true, force: true }); }
}, 60_000);
