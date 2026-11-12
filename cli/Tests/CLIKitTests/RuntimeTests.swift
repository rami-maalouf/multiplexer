import XCTest
@testable import CLIKit
@testable import MatrixCore

func room(_ id: String = "!r:h", name: String = "Room", timestamp: UInt64 = 0) -> RoomSummary {
    RoomSummary(id: id, name: name, isDirect: true, lastMessage: "hello", lastSenderName: "sender", lastIsOwn: false, lastTimestamp: timestamp)
}
func message(_ id: String, at timestamp: UInt64 = 100, text: String = "body") -> Message {
    Message(id: "local-" + id, eventId: id, sender: "@u:h", senderName: "name", body: text,
            timestamp: timestamp, isOwn: false, sendState: .sent, image: nil, reply: nil)
}
func object<T: Encodable>(_ value: T) throws -> [String: Any] {
    var data = Data()
    try jsonLine(value, write: { data = $0 })
    XCTAssertEqual(data.last, 10)
    XCTAssertEqual(data.filter { $0 == 10 }.count, 1)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

final class ResolutionTests: XCTestCase {
    func testExactIdWinsEvenWhenHiddenFoldedOrMatchingAnotherName() throws {
        var hidden = room("!hidden:h"); hidden.isHidden = true
        var folded = room("!fold:h"); folded.foldedInto = "merge:x"
        let rooms = [hidden, folded, room("!other:h", name: "!hidden:h")]
        XCTAssertEqual(try resolve("!hidden:h", in: rooms).id, hidden.id)
        XCTAssertEqual(try resolve("!fold:h", in: rooms).id, folded.id)
    }
    func testOnlyVisibleExactNamesMatch() throws {
        var hidden = room("!hidden:h"); hidden.isHidden = true
        var folded = room("!fold:h"); folded.foldedInto = "merge:x"
        let visible = room()
        XCTAssertEqual(try resolve("Room", in: [hidden, folded, visible]).id, visible.id)
        for query in ["room", "ROOM", " Room", "Roo", "missing"] {
            XCTAssertThrowsError(try resolve(query, in: [visible]))
        }
        XCTAssertThrowsError(try resolve("Room", in: [hidden, folded]))
    }
    func testVisibleDuplicateReportsCandidateIds() {
        XCTAssertThrowsError(try resolve("Room", in: [room("!a:h"), room("!b:h")])) { error in
            XCTAssertEqual(String(describing: error), "ambiguous chat name; use a room id:\n!a:h\tRoom\n!b:h\tRoom")
        }
    }
    func testMergedNameResolvesButUnderlyingIdRemainsAvailable() throws {
        let merged = room("merge:x", name: "Combined")
        var folded = room(); folded.foldedInto = merged.id
        XCTAssertEqual(try resolve("Combined", in: [merged, folded]).id, "merge:x")
        XCTAssertEqual(try resolve(folded.id, in: [merged, folded]).id, folded.id)
    }
}

final class OutputTests: XCTestCase {
    func testMessageJSONLFieldsFlagsReactionsAndEscaping() throws {
        var m = message("$e", at: 123, text: "quote \" slash / backslash \\ newline\n tab\t unicode café")
        m.isOwn = true; m.waitingForKey = true; m.isEdited = true; m.isDeleted = true
        m.reactions = [MessageReaction(key: "reaction\n\"", count: 2, isMine: true), MessageReaction(key: "other", count: 1, isMine: false)]
        let row = try object(MessageLine(m, roomId: "!r:h"))
        XCTAssertEqual(Set(row.keys), ["type", "roomId", "id", "eventId", "sender", "senderName", "text", "timestamp", "isOwn", "waitingForKey", "deleted", "edited", "reactions"])
        XCTAssertEqual(row["text"] as? String, m.body)
        XCTAssertEqual(row["type"] as? String, "message")
        XCTAssertEqual(row["roomId"] as? String, "!r:h")
        XCTAssertEqual(row["id"] as? String, "local-$e")
        XCTAssertEqual(row["eventId"] as? String, "$e")
        XCTAssertEqual(row["sender"] as? String, "@u:h")
        XCTAssertEqual(row["senderName"] as? String, "name")
        XCTAssertEqual(row["timestamp"] as? Int, 123)
        for flag in ["isOwn", "waitingForKey", "deleted", "edited"] { XCTAssertEqual(row[flag] as? Bool, true) }
        let reactions = try XCTUnwrap(row["reactions"] as? [[String: Any]])
        XCTAssertEqual(reactions.count, 2)
        XCTAssertEqual(reactions[0]["key"] as? String, "reaction\n\"")
        XCTAssertEqual(reactions[0]["count"] as? Int, 2)
        XCTAssertEqual(reactions[0]["isMine"] as? Bool, true)
        XCTAssertEqual(reactions[1]["isMine"] as? Bool, false)
    }
    func testMessageJSONLDefaultFlagsAndNoReactions() throws {
        let row = try object(MessageLine(message(""), roomId: "!r:h"))
        XCTAssertEqual(row["eventId"] as? String, "")
        for flag in ["isOwn", "waitingForKey", "deleted", "edited"] { XCTAssertEqual(row[flag] as? Bool, false) }
        XCTAssertEqual((row["reactions"] as? [Any])?.count, 0)
    }
    func testJSONLSortedKeysSingleNewlineAndUnescapedSlashes() throws {
        var data = Data()
        try jsonLine(["z": "line\nnext", "a": "https://host/path"], write: { data = $0 })
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "{\"a\":\"https://host/path\",\"z\":\"line\\nnext\"}\n")
    }
    func testJSONLOutputErrorPropagates() {
        XCTAssertThrowsError(try jsonLine(["x": "y"], write: { _ in throw Failure("disk") }))
    }
    func testMergedReadOrderingLimitAndRoomIdentity() {
        let input = [(message("$c", at: 30), "!b:h"), (message("$a", at: 10), "!a:h"), (message("$b", at: 20), "!b:h")]
        let result = latestMessages(input, limit: 2)
        XCTAssertEqual(result.map { $0.0.eventId }, ["$b", "$c"])
        XCTAssertEqual(result.map { $0.1 }, ["!b:h", "!b:h"])
        XCTAssertEqual(latestMessages(input, limit: 100).map { $0.0.eventId }, ["$a", "$b", "$c"])
        XCTAssertTrue(latestMessages([], limit: 2).isEmpty)
    }
    func testMergedSearchMessagesAndLinksUseDescendingGlobalLimit() {
        let results = newestFirst([message("$a", at: 10), message("$c", at: 30), message("$b", at: 20)], limit: 2, timestamp: { $0.timestamp })
        XCTAssertEqual(results.map(\.eventId), ["$c", "$b"])
        XCTAssertTrue(newestFirst([Message](), limit: 20, timestamp: { $0.timestamp }).isEmpty)
    }
    func testChatJSONPreservesFlagsCountsAndUnderlyingRooms() throws {
        var r = room(timestamp: 456)
        r.unreadCount = 3; r.unreadMentions = 2; r.isMarkedUnread = true
        r.isMuted = true; r.isArchived = true; r.isPinned = true; r.network = "signal"
        let row = try object(Chat(r))
        XCTAssertEqual(row["roomIds"] as? [String], [r.id])
        XCTAssertEqual(row["unread"] as? Int, 3)
        XCTAssertEqual(row["mentions"] as? Int, 2)
        XCTAssertEqual(row["lastTimestamp"] as? Int, 456)
        XCTAssertEqual(row["network"] as? String, "signal")
        for flag in ["markedUnread", "muted", "archived", "pinned", "isDirect"] { XCTAssertEqual(row[flag] as? Bool, true) }
    }
}

final class WatchTests: XCTestCase {
    func testSelectionExcludesSyntheticIdsAndIncludesSelectedUnderlyingRoom() {
        XCTAssertTrue(WatchState.includes("!r:h", selected: nil))
        XCTAssertTrue(WatchState.includes("!r:h", selected: ["!r:h"]))
        XCTAssertFalse(WatchState.includes("!other:h", selected: ["!r:h"]))
        XCTAssertFalse(WatchState.includes("merge:x", selected: nil))
    }
    func testSeedSuppressesInitialHistoryAndUnchangedRoom() {
        var state = WatchState()
        state.seed(room: "!r:h", timestamp: 100, messages: [message("$old")])
        XCTAssertFalse(state.needsSnapshot(room: "!r:h", timestamp: 100))
        XCTAssertTrue(state.needsSnapshot(room: "!r:h", timestamp: 101))
        XCTAssertTrue(state.consume(room: "!r:h", timestamp: 101, messages: [message("$old"), message("$new", at: 101)], started: 100, limit: 20).map(\.eventId) == ["$new"])
    }
    func testTimeWindowBoundaryEmptyIdsAndDedupAcrossSnapshots() {
        var state = WatchState()
        let messages = [message("$old", at: 99), message("", at: 100), message("$at", at: 100), message("$new", at: 101)]
        XCTAssertEqual(state.consume(room: "r", timestamp: 101, messages: messages, started: 100, limit: 20).map(\.eventId), ["$at", "$new"])
        XCTAssertTrue(state.consume(room: "r", timestamp: 101, messages: messages, started: 100, limit: 20).isEmpty)
        XCTAssertEqual(state.consume(room: "other", timestamp: 101, messages: [message("$new", at: 101)], started: 100, limit: 20).count, 1)
    }
    func testLaggingSnapshotIsRetriedUntilRoomTimestampReached() {
        var state = WatchState()
        _ = state.consume(room: "r", timestamp: 110, messages: [message("$a", at: 105)], started: 100, limit: 20)
        XCTAssertTrue(state.needsSnapshot(room: "r", timestamp: 110))
        _ = state.consume(room: "r", timestamp: 110, messages: [message("$b", at: 110)], started: 100, limit: 20)
        XCTAssertFalse(state.needsSnapshot(room: "r", timestamp: 110))
    }
    func testRemovedRoomResetAndProcessRestartCanReplayWithinWindow() {
        var state = WatchState()
        let m = [message("$a", at: 101)]
        _ = state.consume(room: "r", timestamp: 101, messages: m, started: 100, limit: 20)
        state.retain(live: [])
        XCTAssertTrue(state.needsSnapshot(room: "r", timestamp: 101))
        XCTAssertEqual(state.consume(room: "r", timestamp: 101, messages: m, started: 100, limit: 20).count, 1)
        state = WatchState()
        XCTAssertEqual(state.consume(room: "r", timestamp: 101, messages: m, started: 100, limit: 20).count, 1)
    }
    func testBestEffortBurstTruncationAndEvictionReplayAreExplicit() {
        var state = WatchState()
        let burst = (100...104).map { message("$\($0)", at: UInt64($0)) }
        XCTAssertEqual(state.consume(room: "r", timestamp: 104, messages: burst, started: 100, limit: 2).map(\.eventId), ["$103", "$104"])
        // even the truncated ids entered the bounded snapshot's dedupe set.
        XCTAssertTrue(state.consume(room: "r", timestamp: 104, messages: burst, started: 100, limit: 5).isEmpty)
        _ = state.consume(room: "r", timestamp: 105, messages: [message("$105", at: 105)], started: 100, limit: 2)
        XCTAssertEqual(state.consume(room: "r", timestamp: 106, messages: [message("$103", at: 103)], started: 100, limit: 2).map(\.eventId), ["$103"])
    }
    func testUnchangedTimestampDoesNotDetectEditsOrSameTimestampArrival() {
        var state = WatchState()
        state.seed(room: "r", timestamp: 100, messages: [message("$a")])
        XCTAssertFalse(state.needsSnapshot(room: "r", timestamp: 100))
        // the executable skips retrieval here, so edits and another event at 100 may be lost.
    }
}

final class ChatListTests: XCTestCase {
    func testVisibleFilterPrecedesLimitAndPreservesHydrationOrder() {
        var hidden = room("!hidden:h"); hidden.isHidden = true
        var folded = room("!folded:h"); folded.foldedInto = "merge:x"
        let rows = visibleChats([hidden, folded, room("!b:h"), room("!a:h"), room("!c:h")], limit: 2)
        XCTAssertEqual(rows.map(\.id), ["!b:h", "!a:h"])
        XCTAssertEqual(visibleChats([room(), hidden], limit: Int.max).count, 1)
        XCTAssertTrue(visibleChats([], limit: 20).isEmpty)
    }
    func testMergedChatPublishesUnderlyingRoomIdsInMergeOrder() throws {
        var merged = room("merge:x")
        merged.mergeRooms = [MergedRoom(id: "!b:h", network: "signal"), MergedRoom(id: "!a:h", network: "matrix")]
        XCTAssertEqual(try object(Chat(merged))["roomIds"] as? [String], ["!b:h", "!a:h"])
    }
    func testTextModeUsesTabsUnreadCountAndSingleLinePreview() {
        var r = room(); r.network = "signal"; r.lastMessage = "one\ntwo"; r.unreadCount = 2
        XCTAssertEqual(chatText(Chat(r)), "signal\tRoom (2)\tone two")
        r.unreadCount = 0
        XCTAssertEqual(chatText(Chat(r)), "signal\tRoom\tone two")
    }
}
