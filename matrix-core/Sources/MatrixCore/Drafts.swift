import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// Drafts: a chat's unsent text and the message it answers, in the account's store (the sdk's
/// composer draft for the room), so they outlive the app. `send` and `sendAttachment` remove
/// a chat's draft.
extension MatrixAccount {
    /// Keeps a chat's draft; empty text with no reply removes it. `replyTo` is a message's id in
    /// the chat, or the event id a draft keeps ("$…"); a message the server does not have yet is
    /// not kept as the reply.
    public func saveDraft(roomId: String, text: String, replyTo: String? = nil, timeout: TimeInterval = 30) async throws {
        let target = try await room(roomId, timeout: timeout)
        let replyEventId = try await liveTimeline(roomId, limit: 20, timeout: timeout).items.replyEventId(replyTo)
        if text.isEmpty && replyEventId == nil {
            try await target.clearComposerDraft(threadRoot: nil)
            return
        }
        let draft = ComposerDraft(plainText: text, htmlText: nil,
                                  draftType: replyEventId.map { .reply(eventId: $0) } ?? .newMessage, attachments: [])
        try await target.saveComposerDraft(draft: draft, threadRoot: nil)
    }

    /// A chat's kept draft, or nil. Its reply names the message by its id in the open chat, or,
    /// when the chat has not loaded it, by its event id, with its sender and text from the store
    /// or the server. A reply whose message cannot be loaded is left out; the text stays.
    public func draft(roomId: String, timeout: TimeInterval = 30) async throws -> Draft? {
        let target = try await room(roomId, timeout: timeout)
        guard let saved = try await target.loadComposerDraft(threadRoot: nil) else { return nil }
        guard case .reply(let eventId) = saved.draftType else { return Draft(text: saved.plainText, reply: nil) }
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        if let reply = live.items.draftReply(eventId: eventId) { return Draft(text: saved.plainText, reply: reply) }
        guard let event = try? await target.loadOrFetchEvent(eventId: eventId),
              case .messageLike(.roomMessage(let type, _))? = try? event.content() else {
            return Draft(text: saved.plainText, reply: nil)
        }
        let sender = event.senderId()
        let name = ((try? await target.memberDisplayName(userId: sender)) ?? nil) ?? sender
        let me = (try? client.userId()) ?? ""
        return Draft(text: saved.plainText, reply: DraftReply(messageId: eventId, senderName: name, body: preview(type), isOwn: sender == me))
    }
}
