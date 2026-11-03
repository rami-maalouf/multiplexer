import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// A text message that waits on the server and goes at its time, with the phone off: Send
/// Later (B13). The server holds it as a delayed event (MSC4140, Synapse's
/// `max_event_delay_duration`); the sdk's bindings cannot send one, so these calls use the Matrix
/// API with the session's token. A delayed event cannot be end-to-end encrypted, so an encrypted
/// chat has no Send Later (bridged chats are not encrypted).
public struct ScheduledMessage: Equatable, Sendable {
    /// The server's id for it (`delay_id`).
    public var id: String
    public var roomId: String
    public var body: String
    /// When it goes, in milliseconds since 1970.
    public var sendAt: UInt64
    /// The event it answers; nil for none.
    public var replyTo: String?
}

extension MatrixAccount {
    /// Whether the chat can have Send Later: a chat that is not end-to-end encrypted.
    public func canSendLater(roomId: String, timeout: TimeInterval = 30) async throws -> Bool {
        let target = try await room(roomId, timeout: timeout)
        return try await target.latestEncryptionState() == .notEncrypted
    }

    /// Puts `text` on the server to go at `at`, answering `replyTo` (a message's id in the open
    /// chat, or an event id) when given: its id. The chat shows it only once it goes.
    @discardableResult
    public func sendLater(roomId: String, text: String, replyTo: String? = nil, at: Date, timeout: TimeInterval = 30) async throws -> String {
        guard try await canSendLater(roomId: roomId, timeout: timeout) else { throw MatrixCoreError.scheduleEncrypted(roomId) }
        var content: [String: Any] = ["msgtype": "m.text", "body": text]
        let replyEvent: String?
        if let replyTo, replyTo.hasPrefix("$") {
            replyEvent = replyTo
        } else {
            replyEvent = try await liveTimeline(roomId, limit: 20, timeout: timeout).items.replyEventId(replyTo)
        }
        if let replyEvent { content["m.relates_to"] = ["m.in_reply_to": ["event_id": replyEvent]] }
        return try await schedule(roomId: roomId, content: content, at: at)
    }

    /// The messages waiting on the server, the soonest first.
    public func scheduledMessages() async throws -> [ScheduledMessage] {
        let answer = try await delayedEventsAPI("GET", [])
        let events = answer["delayed_events"] as? [[String: Any]] ?? []
        return events.compactMap(ScheduledMessage.init(delayed:)).sorted { ($0.sendAt, $0.id) < ($1.sendAt, $1.id) }
    }

    /// Sends a waiting message now.
    public func sendScheduledNow(id: String) async throws {
        _ = try await delayedEventsAPI("POST", [id, "send"], body: [:])
    }

    /// Cancels a waiting message: it never goes.
    public func cancelScheduled(id: String) async throws {
        _ = try await delayedEventsAPI("POST", [id, "cancel"], body: [:])
    }

    /// Moves a waiting message to `at`: the server cannot change a delay, so a new one waits
    /// with the same content, then the old one is cancelled. If the old one went meanwhile, the
    /// new one is cancelled too and this throws `scheduleGone`. The new one's id.
    @discardableResult
    public func reschedule(id: String, at: Date) async throws -> String {
        let answer = try await delayedEventsAPI("GET", [])
        guard let old = (answer["delayed_events"] as? [[String: Any]] ?? []).first(where: { $0["delay_id"] as? String == id }),
              let roomId = old["room_id"] as? String, let content = old["content"] as? [String: Any] else {
            throw MatrixCoreError.scheduleGone(id)
        }
        let new = try await schedule(roomId: roomId, content: content, at: at)
        do {
            try await cancelScheduled(id: id)
        } catch {
            try? await cancelScheduled(id: new)
            throw MatrixCoreError.scheduleGone(id)
        }
        return new
    }

    /// A message event of `content` that the server sends at `at`: its id.
    private func schedule(roomId: String, content: [String: Any], at: Date) async throws -> String {
        let delay = Int64((at.timeIntervalSinceNow * 1000).rounded())
        guard delay > 0 else { throw MatrixCoreError.scheduleRefused("the time is past") }
        let session = try savedSession()
        guard var url = URLComponents(url: try Self.apiURL(session, "v3", ["rooms", roomId, "send", "m.room.message", UUID().uuidString]),
                                      resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
        url.queryItems = [URLQueryItem(name: "org.matrix.msc4140.delay", value: String(delay))]
        let answer = try await Self.call("PUT", url.url!, body: content, session: session)
        guard let id = answer["delay_id"] as? String else { throw MatrixCoreError.scheduleRefused("the server did not hold it") }
        return id
    }

    /// The delayed events api (`/_matrix/client/unstable/org.matrix.msc4140/delayed_events/...`).
    private func delayedEventsAPI(_ method: String, _ path: [String], body: [String: Any]? = nil) async throws -> [String: Any] {
        let session = try savedSession()
        return try await Self.call(method, try Self.apiURL(session, "unstable/org.matrix.msc4140", ["delayed_events"] + path),
                                   body: body, session: session)
    }

    private static func apiURL(_ session: SavedSession, _ version: String, _ path: [String]) throws -> URL {
        guard var url = URL(string: session.homeserverUrl) else { throw URLError(.badURL) }
        url.appendPathComponent("_matrix/client/\(version)")
        for part in path { url.appendPathComponent(part) }
        return url
    }

    /// One request with the session's token: its JSON answer. A refusal throws with the
    /// server's `errcode`: `M_UNKNOWN`/`M_NOT_FOUND` for a delay gone, and a delay too long.
    private static func call(_ method: String, _ url: URL, body: [String: Any]?, session: SavedSession) async throws -> [String: Any] {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = method
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let answer = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let code = answer["errcode"] as? String ?? "HTTP \(status)", text = answer["error"] as? String ?? ""
            if status == 404 { throw MatrixCoreError.scheduleGone("\(code) \(text)") }
            throw MatrixCoreError.scheduleRefused("\(code) \(text)")
        }
        return answer
    }
}

extension ScheduledMessage {
    /// When a Send Later choice goes, in the reader's calendar and zone: "tomorrow" (9:00 the
    /// next day), "monday" (the next Monday at 9:00), or a time the picker gives without a zone
    /// ("2026-11-04T09:30", HTML's `datetime-local`). Nil for another text.
    public static func date(for choice: String, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch choice {
        case "tomorrow":
            guard let next = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: next)
        case "monday":
            return calendar.nextDate(after: now, matching: DateComponents(hour: 9, minute: 0, second: 0, weekday: 2),
                                     matchingPolicy: .nextTime)
        default:
            let format = DateFormatter()
            format.calendar = Calendar(identifier: .gregorian)
            format.locale = Locale(identifier: "en_US_POSIX")
            format.timeZone = calendar.timeZone
            for pattern in ["yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd'T'HH:mm:ss"] {
                format.dateFormat = pattern
                if let date = format.date(from: choice) { return date }
            }
            return nil
        }
    }

    /// A waiting text message from the server's list; nil for another delayed event (a call's).
    init?(delayed: [String: Any]) {
        guard let id = delayed["delay_id"] as? String, let roomId = delayed["room_id"] as? String,
              delayed["type"] as? String == "m.room.message", delayed["state_key"] == nil,
              let content = delayed["content"] as? [String: Any], let body = content["body"] as? String else { return nil }
        let delay = (delayed["delay_ms"] ?? delayed["delay"]) as? NSNumber
        let since = (delayed["delayed_since_ts"] ?? delayed["running_since"]) as? NSNumber
        guard let delay, let since else { return nil }
        let reply = ((content["m.relates_to"] as? [String: Any])?["m.in_reply_to"] as? [String: Any])?["event_id"] as? String
        self.init(id: id, roomId: roomId, body: body, sendAt: since.uint64Value + delay.uint64Value, replyTo: reply)
    }
}
