import Foundation

/// What a chat shows as it opens (R04): its messages at once, from what this device has kept of
/// it, and whether more is still on its way (`settling`): the rest of its first screen, or a page
/// back to a "New" line further back than it shows. The chat hears when that is in
/// (`MatrixChange.room`) and asks again.
public struct ChatOpening: Sendable {
    public var messages: [Message]
    /// The first unread message's id ("New" line), nil for none or not known yet.
    public var firstUnread: String?
    public var atStart: Bool
    public var settling: Bool
}

extension MatrixAccount {
    /// The chat's messages for its screen. The first time on this device's session it answers as
    /// soon as the timeline has a message; a chat already open answers from it, with its "New"
    /// line (paging back to it once when it is older than what the chat shows).
    public func opening(roomId: String, limit: Int, timeout: TimeInterval = 30) async throws -> ChatOpening {
        let live = try await liveTimeline(roomId, limit: limit, timeout: timeout)
        // a timeline reset (a sync with a gap, as a new device's first sync or a return after a long
        // time away has) leaves only the newest messages: the chat fills its first screen again.
        live.startFill(to: limit) { [weak self] paged in if paged { self?.notify(.room(roomId)) } }
        if live.isFilling {
            let firstUnread = try? await firstUnread(roomId: roomId, pageBack: false, timeout: timeout)
            let messages = try await messagesNow(roomId: roomId, limit: limit, timeout: timeout)
            return ChatOpening(messages: messages, firstUnread: firstUnread ?? nil, atStart: false, settling: true)
        }
        // first, as it may page the chat back to it: the messages then hold it.
        let firstUnread = try? await firstUnread(roomId: roomId, timeout: timeout)
        let messages = try await messages(roomId: roomId, limit: limit, timeout: timeout)
        let atStart = try await isAtStart(roomId: roomId, timeout: timeout)
        return ChatOpening(messages: messages, firstUnread: firstUnread ?? nil, atStart: atStart, settling: false)
    }
}
