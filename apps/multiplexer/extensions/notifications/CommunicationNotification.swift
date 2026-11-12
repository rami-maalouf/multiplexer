import Foundation
import Intents
import UserNotifications
import ImageIO
import UniformTypeIdentifiers
import UIKit

enum CommunicationNotification {
    static func intent(for shown: PushContent, avatar: Data?) -> INSendMessageIntent {
        let image = INImage(imageData: avatar.flatMap(thumbnail) ?? initials(shown.senderName))
        let sender = INPerson(personHandle: INPersonHandle(value: shown.senderId, type: .unknown),
                              nameComponents: PersonNameComponentsFormatter().personNameComponents(from: shown.senderName),
                              displayName: shown.senderName, image: image, contactIdentifier: nil, customIdentifier: shown.senderId)
        let intent = INSendMessageIntent(recipients: nil, outgoingMessageType: .outgoingMessageText, content: shown.body,
                                         speakableGroupName: shown.isDirect ? nil : INSpeakableString(spokenPhrase: shown.chatName),
                                         conversationIdentifier: shown.roomId, serviceName: nil, sender: sender, attachments: nil)
        let metadata = INSendMessageIntentDonationMetadata()
        metadata.recipientCount = shown.otherRecipientCount
        metadata.mentionsCurrentUser = shown.hasMention
        intent.donationMetadata = metadata
        return intent
    }

    static func content(_ content: UNNotificationContent, shown: PushContent, avatar: Data?) async -> UNNotificationContent {
        let intent = intent(for: shown, avatar: avatar)
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming
        do {
            try await interaction.donate()
            guard let updated = try content.updating(from: intent).mutableCopy() as? UNMutableNotificationContent else { return content }
            // communication styling must retain the chat title, sender subtitle and preview.
            updated.title = content.title
            updated.subtitle = content.subtitle
            updated.body = content.body
            return updated
        } catch {
            // system personalization or photo failures must never hide a message.
            return content
        }
    }

    private static func initials(_ name: String) -> Data {
        let words = name.split(whereSeparator: { $0.isWhitespace })
        let text = (words.count > 1
            ? String(words.first!.prefix(1)) + String(words.last!.prefix(1))
            : String(name.prefix(2))).uppercased()
        return UIGraphicsImageRenderer(size: CGSize(width: 160, height: 160)).pngData { context in
            UIColor.darkGray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 160, height: 160))
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 64, weight: .medium),
                                                            .foregroundColor: UIColor.white]
            let size = (text as NSString).size(withAttributes: attributes)
            (text as NSString).draw(at: CGPoint(x: (160 - size.width) / 2, y: (160 - size.height) / 2), withAttributes: attributes)
        }
    }

    private static func thumbnail(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: 160, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
        let result = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(result, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? result as Data : nil
    }
}
