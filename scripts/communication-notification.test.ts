import { expect, test } from 'bun:test';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

const simulator = process.env.SIMULATOR;
test.skipIf(!simulator)('communication intents use sender identity and photo without losing group context', () => {
  const directory = mkdtempSync(join(tmpdir(), 'mux-communication-'));
  try {
    const fixture = join(directory, 'Fixture.swift');
    writeFileSync(fixture, `
import Foundation
import UIKit
import Intents
import UserNotifications
struct PushContent {
    var senderId = "@test2:example.org"; var senderName = "Test Sender"; var body = "Message text"
    var roomId = "!room:example.org"; var chatName = "Test Group"; var isDirect = true
    var otherRecipientCount = 0; var hasMention = false
}
@main struct Check {
    @MainActor static func main() async {
        let picture = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).pngData { context in
            UIColor.systemBlue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
        var shown = PushContent()
        let direct = CommunicationNotification.intent(for: shown, avatar: picture)
        precondition(direct.sender?.personHandle?.value == shown.senderId)
        precondition(direct.sender?.displayName == shown.senderName)
        precondition(direct.sender?.image != nil, "the sender's profile photo is missing")
        precondition(direct.content == shown.body)
        precondition(direct.conversationIdentifier == shown.roomId)
        precondition(direct.speakableGroupName == nil)
        shown.isDirect = false; shown.otherRecipientCount = 3; shown.hasMention = true
        let group = CommunicationNotification.intent(for: shown, avatar: picture)
        precondition(group.speakableGroupName?.spokenPhrase == shown.chatName)
        precondition(group.sender?.image != nil)
        precondition((group.donationMetadata as? INSendMessageIntentDonationMetadata)?.recipientCount == 3)
        precondition((group.donationMetadata as? INSendMessageIntentDonationMetadata)?.mentionsCurrentUser == true)
        let missing = CommunicationNotification.intent(for: shown, avatar: nil)
        let invalid = CommunicationNotification.intent(for: shown, avatar: Data("bad image".utf8))
        precondition(missing.sender?.image != nil && invalid.sender?.image != nil, "initials fallback is missing")
        precondition(invalid.content == shown.body)
        let original = UNMutableNotificationContent()
        original.title = "Test Group"; original.subtitle = "Test Sender"; original.body = "Message text"
        original.userInfo = NotificationActivation.userInfo(["room_id": shown.roomId, "event_id": "$event"], userId: "@test1:example.org")
        let delivered = await CommunicationNotification.content(original, shown: shown, avatar: picture)
        precondition(delivered.title == original.title && delivered.subtitle == original.subtitle && delivered.body == original.body)
        precondition(NSDictionary(dictionary: delivered.userInfo).isEqual(to: original.userInfo), "communication styling lost the tap destination")
        print("sender photo, missing/corrupt photo and group context passed")
    }
}
`);
    const sdk = Bun.spawnSync(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path']).stdout.toString().trim();
    const binary = join(directory, 'check');
    const compile = Bun.spawnSync(['xcrun', 'swiftc', '-parse-as-library', '-sdk', sdk,
      '-target', 'arm64-apple-ios17.0-simulator', resolve(import.meta.dir, '../apps/multiplexer/extensions/notifications/CommunicationNotification.swift'),
      resolve(import.meta.dir, '../apps/multiplexer/extensions/notifications/NotificationActivation.swift'),
      fixture, '-o', binary]);
    if (compile.exitCode !== 0) throw new Error(compile.stderr.toString());
    const result = Bun.spawnSync(['xcrun', 'simctl', 'spawn', simulator!, binary]);
    if (result.exitCode !== 0) throw new Error(result.stderr.toString());
    expect(result.stdout.toString()).toContain('group context passed');
  } finally { rmSync(directory, { recursive: true, force: true }); }
}, 60_000);
