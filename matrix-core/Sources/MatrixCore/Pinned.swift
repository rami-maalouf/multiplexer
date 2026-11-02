import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// Pinned chats. A pin is the room's `m.favourite` tag, with its `order` (0 to 1) as the
/// pin's place, so the account's other devices show the same pins in the same order.
extension MatrixAccount {
    /// Pins a chat after the chats pinned before it. It shows as pinned at once; the server
    /// confirms it with the next sync.
    public func pin(roomId: String, timeout: TimeInterval = 30) async throws {
        let target = try await room(roomId, timeout: timeout)
        var pinned = Self.inPinOrder(try await rooms(timeout: timeout)).filter { $0.id != roomId }
        if Pins.next(after: pinned) == nil {
            // the gaps between the orders are used up: spread the pins out again, in their order.
            for (i, summary) in pinned.enumerated() {
                let order = Double(i + 1) / Double(pinned.count + 1)
                try await room(summary.id, timeout: timeout).setIsFavourite(isFavourite: true, tagOrder: order)
                pins.know(summary.id, order: order)
                pinned[i].pinOrder = order
            }
        }
        let order = Pins.next(after: pinned)
        pins.expect(roomId, pinned: true)
        do {
            try await target.setIsFavourite(isFavourite: true, tagOrder: order)
        } catch {
            pins.expect(roomId, pinned: nil)
            throw error
        }
        pins.know(roomId, order: order)
        notify(.rooms)
    }

    /// Unpins a chat: it goes back to its place in the list.
    public func unpin(roomId: String, timeout: TimeInterval = 30) async throws {
        let target = try await room(roomId, timeout: timeout)
        pins.expect(roomId, pinned: false)
        do {
            try await target.setIsFavourite(isFavourite: false, tagOrder: nil)
        } catch {
            pins.expect(roomId, pinned: nil)
            throw error
        }
        pins.forget(roomId)
        notify(.rooms)
    }

    /// The pinned chats in their pin order: by `pinOrder`, then those with none (pinned by a
    /// client that sets no order) in the list's order.
    static func inPinOrder(_ rooms: [RoomSummary]) -> [RoomSummary] {
        rooms.enumerated().filter { $0.element.isPinned }
            .sorted { ($0.element.pinOrder ?? .infinity, $0.offset) < ($1.element.pinOrder ?? .infinity, $1.offset) }
            .map(\.element)
    }

    /// Gives each pinned chat its order. The sdk does not say a tag's order, so the first time
    /// a chat shows as pinned its tags are read from the server (all at once); later the order
    /// is the one known here. A failed read leaves the order unknown, to be read next time.
    func fillPinOrders(_ rooms: inout [RoomSummary]) async {
        let missing = rooms.filter { $0.isPinned && pins.order(of: $0.id) == nil }.map(\.id)
        if !missing.isEmpty, let session = try? client.session() {
            await withTaskGroup(of: (String, Double??).self) { group in
                for roomId in missing {
                    group.addTask { (roomId, try? await favouriteOrder(roomId: roomId, session: session)) }
                }
                for await (roomId, order) in group {
                    if let order { pins.know(roomId, order: order) }
                }
            }
        }
        for i in rooms.indices {
            if rooms[i].isPinned {
                rooms[i].pinOrder = pins.order(of: rooms[i].id) ?? nil
            } else {
                // unpinned, here or elsewhere: a pin from another device reads its order again.
                pins.forget(rooms[i].id)
            }
        }
    }
}

/// The room's `m.favourite` order from the server (`GET .../rooms/{roomId}/tags`); nil when
/// the tag has no order, or the room has no such tag.
private func favouriteOrder(roomId: String, session: Session) async throws -> Double? {
    guard let base = URL(string: session.homeserverUrl) else { throw URLError(.badURL) }
    let url = base.appendingPathComponent("_matrix/client/v3/user").appendingPathComponent(session.userId)
        .appendingPathComponent("rooms").appendingPathComponent(roomId).appendingPathComponent("tags")
    var request = URLRequest(url: url, timeoutInterval: 10)
    request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    let tags = (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["tags"] as? [String: Any]
    return ((tags?["m.favourite"] as? [String: Any])?["order"] as? NSNumber)?.doubleValue
}

/// What this device knows of the pins: each pinned chat's order, and the pins asked for here
/// that the server has not confirmed yet.
final class Pins: @unchecked Sendable {
    private let lock = NSLock()
    /// The order of each pinned chat that is known here (an inner nil: the pin has no order).
    private var orders: [String: Double?] = [:]
    /// Pinned (true) or unpinned (false) here, until the room list agrees.
    private var expected: [String: Bool] = [:]

    /// Whether a chat shows as pinned: as asked here, until the server says the same.
    func isPinned(_ roomId: String, onServer: Bool) -> Bool {
        lock.withLock {
            guard let wanted = expected[roomId] else { return onServer }
            if wanted == onServer { expected[roomId] = nil }
            return wanted
        }
    }

    /// Records a pin or an unpin asked for here; nil forgets it (the server refused it).
    func expect(_ roomId: String, pinned: Bool?) {
        lock.withLock { expected[roomId] = pinned }
    }

    /// The pin's order: nil when not known here, `.some(nil)` when the pin has none.
    func order(of roomId: String) -> Double?? {
        lock.withLock { orders[roomId] }
    }

    func know(_ roomId: String, order: Double?) {
        lock.withLock { orders[roomId] = .some(order) }
    }

    func forget(_ roomId: String) {
        lock.withLock { _ = orders.removeValue(forKey: roomId) }
    }

    /// The order for a new pin after `pinned`: halfway from the last order to 1. Nil when
    /// that would not fit between them (about 30 pins added in a row without a gap).
    static func next(after pinned: [RoomSummary]) -> Double? {
        let last = pinned.compactMap(\.pinOrder).max() ?? 0
        let next = (last + 1) / 2
        return last < 1 && 1 - next > 1e-9 ? next : nil
    }
}
