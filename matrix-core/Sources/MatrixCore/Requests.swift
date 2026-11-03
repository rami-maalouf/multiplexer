import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// A request: a chat this account is invited to and has not answered, as Beeper's Requests row
/// lists them. Accept joins the chat, which then shows in the list; Decline leaves it.
/// (A bridge's message request, such as Instagram's, is not an invite: not built, see
/// `tasks/todo.md`, L3.)
public struct ChatRequest: Equatable, Sendable {
    public var id: String
    public var name: String
    public var isDirect: Bool
    /// The chat's picture, as `RoomSummary.avatarName` names a room's ("" for none).
    public var avatarName: String
    /// Who invited this account: their id and name ("" when the invite does not say).
    public var inviterId: String
    public var inviterName: String
}

extension MatrixAccount {
    /// The chats this account is invited to (no spaces), after the first sync, in the room
    /// list's order: the most recent first.
    public func requests(timeout: TimeInterval = 30) async throws -> [ChatRequest] {
        try await startSync(timeout: timeout)
        var requests: [ChatRequest] = []
        for room in client.rooms() where room.membership() == .invited && !room.isSpace() {
            let inviter = try? await room.inviter()
            requests.append(ChatRequest(id: room.id(), name: room.displayName() ?? room.id(), isDirect: await room.isDirect(),
                                        avatarName: room.avatarUrl().map(avatarFileName) ?? "",
                                        inviterId: inviter?.userId ?? "", inviterName: inviter?.displayName ?? ""))
        }
        let order = rankedRoomIds()
        let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return requests.enumerated().sorted { (rank[$0.element.id] ?? Int.max, $0.offset) < (rank[$1.element.id] ?? Int.max, $1.offset) }
            .map(\.element)
    }

    /// Accepts a request: this account joins the chat.
    public func accept(request roomId: String, timeout: TimeInterval = 30) async throws {
        try await room(roomId, timeout: timeout).join()
    }

    /// Declines a request: the invite is refused, and the chat leaves Requests.
    public func decline(request roomId: String, timeout: TimeInterval = 30) async throws {
        try await room(roomId, timeout: timeout).leave()
    }
}
