import { expect, test } from 'bun:test';
import { createHash } from 'node:crypto';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

test('remote activation reaches the pinned native receiver once with account and room intact', () => {
  const exact = resolve(import.meta.dir, '../apps/multiplexer', process.env.EXACT2 ?? '../../../exact/expo-exact');
  const receiver = join(exact, 'host/apple/Sources/ExactKit/Notify.swift');
  // an exact upgrade must revalidate this private contract, including lifecycle delivery.
  expect(createHash('sha256').update(readFileSync(receiver)).digest('hex'))
    .toBe('04b865e2252721775e14b577ee19079632b640edeacf72459dc89973e2974be7');
  const directory = mkdtempSync(join(tmpdir(), 'mux-notification-activation-'));
  try {
    writeFileSync(join(directory, 'main.swift'), String.raw`
import Foundation
import UserNotifications
enum SessionState { case active, destroyed }
final class ExactSession {
    let label = "main"; let notificationOwnerID = "app-owner"
    var state = SessionState.active
    var events: [(String, String, String, Bool)] = []
    func log(_ line: String) {}
    func openLocation(_ location: String) { preconditionFailure("bypassed the account-aware handler") }
    func raiseModuleEvent(extension name: String, event: String, args: String, activation: Bool) {
        events.append((name, event, args, activation))
    }
}
final class ExactApp { let sessions = [ExactSession()]; let notificationProcessID = "app-process" }
let account = "@test:example.org", room = "!room\"\\:example.org"
let raw: [AnyHashable: Any] = ["room_id": room, "event_id": "$event", "unread_count": 4,
                              "aps": ["alert": ["body": "New message"]]]
let app = ExactApp(), presenter = NotificationPresenter(), date = Date()
presenter.app = app
presenter.deliver(id: "baseline", date: date, info: raw)
precondition(app.sessions[0].events.isEmpty, "baseline should reproduce dropped raw pushes")
let info = NotificationActivation.userInfo(raw, userId: account)
precondition(info["unread_count"] as? Int == 4)
precondition((info["aps"] as? NSDictionary) == (raw["aps"] as? NSDictionary))
presenter.deliver(id: "message", date: date, info: info)
presenter.deliver(id: "message", date: date, info: info)
precondition(app.sessions[0].events.count == 1, "tap must reach the host once")
let event = app.sessions[0].events[0]
precondition(event.0 == "notifications" && event.1 == "notificationclick" && event.3)
let args = try JSONSerialization.jsonObject(with: Data(event.2.utf8)) as! [Any]
precondition(args[0] as? String == "chat:\(account):\(room)")
let detail = args[1] as! [String: Any]
precondition(detail["data"] as? String == room && detail["tag"] as? String == args[0] as? String)
precondition(detail["body"] is NSNull && detail["title"] as? String == "")
// a new app process resolves the same banner by session label, not the old owner id.
let relaunched = ExactApp(), cold = NotificationPresenter()
cold.app = relaunched
cold.deliver(id: "message", date: date, info: info)
precondition(relaunched.sessions[0].events.count == 1)
var injected = raw
injected["exact"] = info["exact"]; injected["navigate"] = "/room/other"
for owner: String? in [nil, ""] {
    let refused = NotificationActivation.userInfo(injected, userId: owner)
    precondition(refused["exact"] == nil && refused["navigate"] == nil)
}
for key in ["room_id", "event_id"] {
    for invalid: Any in ["", 7, NSNull()] {
        var malformed = injected; malformed[key] = invalid
        precondition(NotificationActivation.userInfo(malformed, userId: account)["exact"] == nil)
    }
}
func notice(_ id: String, _ payload: [AnyHashable: Any]) -> UNNotificationRequest {
    let content = UNMutableNotificationContent(); content.userInfo = payload
    return UNNotificationRequest(identifier: id, content: content, trigger: nil)
}
let anotherAccount = NotificationActivation.userInfo(raw, userId: "@other:example.org")
let anotherRoom = NotificationActivation.userInfo(["room_id": "!other:example.org", "event_id": "$other"], userId: account)
var malformed = info
malformed["exact"] = ["extension": "notifications", "event": "notificationclick", "args": "not json"]
let delivered = [notice("first", info), notice("second", info), notice("another-account", anotherAccount),
                 notice("another-room", anotherRoom), notice("unscoped", raw), notice("malformed", malformed)]
precondition(ChatNotifications.identifiers(delivered, userId: account, roomId: room) == ["first", "second"],
             "opening a chat must clear every matching system identifier and retain other accounts and rooms")
precondition(ChatNotifications.identifiers(delivered, userId: "", roomId: room).isEmpty)
precondition(ChatNotifications.identifiers(delivered, userId: account, roomId: "").isEmpty)
print("native notification activation passed")
`);
    const binary = join(directory, 'check');
    const compile = Bun.spawnSync(['xcrun', 'swiftc', receiver,
      resolve(import.meta.dir, '../apps/multiplexer/extensions/notifications/NotificationActivation.swift'),
      resolve(import.meta.dir, '../apps/multiplexer/modules/apple/ChatNotifications.swift'),
      join(directory, 'main.swift'), '-o', binary]);
    if (compile.exitCode !== 0) throw new Error(compile.stderr.toString());
    const result = Bun.spawnSync([binary]);
    if (result.exitCode !== 0) throw new Error(result.stderr.toString());
    expect(result.stdout.toString()).toContain('native notification activation passed');
  } finally { rmSync(directory, { recursive: true, force: true }); }
}, 60_000);
