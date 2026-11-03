import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// The message search index. The sdk keeps it on this device, one index per chat in the
/// account's store folder, encrypted with a key the app keeps in the Keychain, and fills it with
/// every message the device syncs or pages back; its backfill pages every chat back 3 months.
/// The server takes no part. matrix-core/NOTES.md, "Search", has its size and limits.
public enum SearchIndex {
    /// A new key for an index: 32 random bytes as hex. The app keeps it with the session
    /// (`StoredSession.searchKey`), in the Keychain, never in a file.
    public static func newKey() -> String {
        var generator = SystemRandomNumberGenerator()
        return (0..<32).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max, using: &generator)) }.joined()
    }

    /// The index's folder in an account's store folder.
    static func directory(in store: URL) -> URL { store.appendingPathComponent("search", isDirectory: true) }

    /// The words the index knows a text by: its runs of letters and digits, in lower case, as
    /// the index splits a message (tantivy's default tokenizer).
    static func words(_ text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    /// The index's query for `words`: a message must have every one, as a whole word (the sdk's
    /// tantivy 0.27 refuses a one-word prefix and regexes, so a word's start finds nothing).
    /// `also` adds a group of which a message must have one (a kind's words).
    static func query(_ words: [String], also: [String] = []) -> String {
        var terms = words.map { "+\($0)" }
        if !also.isEmpty { terms.append("+(\(also.joined(separator: " ")))") }
        return terms.joined(separator: " ")
    }

    /// A text without case or accents, to compare names.
    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).lowercased()
    }

    /// The web links in a text, as the chat shows them: from http://, https:// or www. to the
    /// next space; a sentence's punctuation after one, and a bracket it did not open, are not
    /// part of it (app.ts's `runsOf` reads them the same way).
    static func links(in text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        return linkPattern.matches(in: text, range: range).compactMap { found in
            guard let r = Range(found.range, in: text) else { return nil }
            let link = linkEnd(String(text[r]))
            return link.count < 5 ? nil : link
        }
    }

    private static let linkPattern = try! NSRegularExpression(pattern: #"\b(?:https?://|www\.)[^\s<>"]+"#, options: [.caseInsensitive])

    private static func linkEnd(_ url: String) -> String {
        var end = url
        func count(_ c: Character) -> Int { end.filter { $0 == c }.count }
        while let last = end.last {
            if ".,;:!?'\"’”".contains(last) { end.removeLast() }
            else if last == ")" && count(")") > count("(") { end.removeLast() }
            else if last == "]" && count("]") > count("[") { end.removeLast() }
            else { break }
        }
        return end
    }
}

/// The kinds a search shows across chats or in one chat (audio: one chat only), newest first,
/// with or without words.
public enum SearchKind: String, CaseIterable, Sendable {
    case images, videos, links, files, audio

    /// Words in the messages of this kind, of which a message must have one. The index holds a
    /// photo's, video's or file's file name and caption, so the kinds go by the file name's
    /// extension and what bridges name them ("image.jpg", "video.mp4"); a file with none of these
    /// is not found under its kind. A link starts with http, https or www.
    var indexWords: [String] {
        switch self {
        case .images: return ["image", "photo", "img", "screenshot", "jpg", "jpeg", "png", "gif", "webp", "heic", "heif"]
        case .videos: return ["video", "mp4", "mov", "m4v", "webm", "3gp", "mkv", "avi"]
        case .links: return ["http", "https", "www"]
        case .files: return ["document", "file", "pdf", "doc", "docx", "xls", "xlsx", "csv", "ppt", "pptx", "key", "pages",
                             "numbers", "txt", "rtf", "md", "zip", "rar", "7z", "gz", "json", "xml", "html", "epub", "apk",
                             "dmg", "ics", "vcf", "psd", "svg", "sketch", "fig"]
        case .audio: return ["audio", "voice", "ogg", "opus", "m4a", "mp3", "aac", "wav", "amr"]
        }
    }

    /// The message types of this kind, for a chat's timeline of them (`chatKind`). A link has no
    /// type: it is found in a text's words. Photos and videos share the info page's timeline.
    var messageTypes: [RoomMessageEventMessageType] {
        switch self {
        case .images, .videos: return [.image, .video]
        case .links: return [.text, .notice, .emote]
        case .files: return [.file]
        case .audio: return [.audio]
        }
    }

    func has(_ message: FoundMessage) -> Bool {
        switch self {
        case .images: return message.kind == .image
        case .videos: return message.kind == .video
        case .links: return !message.links.isEmpty
        case .files: return message.kind == .file
        case .audio: return message.kind == .audio
        }
    }
}

/// A message a search found.
public struct FoundMessage: Equatable, Sendable {
    public enum Kind: String, Sendable { case text, image, video, audio, file, other }

    /// Its chat, as the list shows it.
    public var chat: RoomSummary
    public var eventId: String
    public var sender: String
    public var senderName: String
    public var isOwn: Bool
    /// Its text; a photo's, video's, voice note's or file's caption ("" for none).
    public var body: String
    /// Milliseconds since 1970.
    public var timestamp: UInt64
    public var kind: Kind
    /// The web links in `body`, as written ("https://…", "www.…").
    public var links: [String]
    /// A photo's picture, with the name `searchPicture` gives its thumbnail; nil for others.
    public var image: MessageImage?
    /// A video, with the name `searchPicture` gives its poster; nil for others.
    public var video: MessageVideo?
    /// A file's name and size; an audio file's too (a voice message's name is the sdk's).
    public var file: MessageFile?
    /// A voice message's or audio file's sound; nil for others.
    public var audio: MessageAudio? = nil
    /// The sender's picture's media url; "" for none.
    public var senderPicture: String = ""

    /// The file name `MatrixAccount.pictureFile` gives the sender's picture; "" for none.
    public var senderPictureName: String { senderPicture.isEmpty ? "" : avatarFileName(senderPicture) }
}

/// What a search for words finds, in the order the screen shows it (Rami, 2026-11-02).
public struct SearchResults: Equatable, Sendable {
    /// Chats whose name has the words, the best match first (`chatsNamed`).
    public var chats: [RoomSummary]
    /// Messages with the words, the newest first, but those under `links`.
    public var messages: [FoundMessage]
    /// Messages with a link that has one of the words, the newest first.
    public var links: [FoundMessage]
}

/// How far the search index is, for the log.
public struct SearchIndexStatus: Equatable, Sendable {
    /// The backfill has paged every chat back 3 months, or as far as each goes.
    public var backfillDone: Bool
    /// Since the backfill started, to its end once it is done; 0 before it starts.
    public var backfillSeconds: Double
    /// The index on disk, in bytes; nil when the sdk does not know.
    public var indexBytes: UInt64?
    /// The sdk's event cache, which the backfill fills too, in bytes.
    public var eventCacheBytes: UInt64?
}

/// The search's own state on an account: its backfill, and the pictures of the messages found.
final class SearchState: @unchecked Sendable {
    fileprivate struct Picture {
        let source: MediaSource?
        let thumbnail: MediaSource?
        let name: String
    }

    private let lock = NSLock()
    private var backfill: TaskHandle?
    private var started: Date?
    private var ended: Date?
    private var pictures: [String: Picture] = [:]
    /// The timelines of one kind (`chatKind`) of one chat at a time, `room`: those of another
    /// chat close when it opens one. By kind.
    private var room = ""
    private var timelines: [SearchKind: Task<MediaTimeline, Error>] = [:]
    /// Each kind's paging back, and the count it pages back for.
    private var pagings: [SearchKind: (limit: Int, task: Task<Void, Error>)] = [:]

    /// The chat's timeline of `kind`: the one opening or open, else the one `open` starts.
    func timeline(_ kind: SearchKind, _ roomId: String, open: @escaping @Sendable () async throws -> MediaTimeline) -> Task<MediaTimeline, Error> {
        lock.withLock {
            if roomId != room { (room, timelines, pagings) = (roomId, [:], [:]) }
            if let made = timelines[kind] { return made }
            let task = Task { try await open() }
            timelines[kind] = task
            return task
        }
    }

    func forgetTimeline(_ kind: SearchKind, _ roomId: String) {
        lock.withLock { if roomId == room { (timelines[kind], pagings[kind]) = (nil, nil) } }
    }

    /// The chat's paging back of `kind` for `limit` messages: it pages back once, and a later ask
    /// for no more waits for that one, so the words typed on a kind's page read what it holds.
    func paging(_ kind: SearchKind, _ roomId: String, _ limit: Int, page: @escaping @Sendable () async throws -> Void) -> Task<Void, Error> {
        lock.withLock {
            if roomId != room { (room, timelines, pagings) = (roomId, [:], [:]) }
            if let made = pagings[kind], made.limit >= limit { return made.task }
            let task = Task { try await page() }
            pagings[kind] = (limit, task)
            return task
        }
    }

    func start(_ handle: TaskHandle) {
        lock.withLock {
            backfill?.cancel()
            backfill = handle
            started = Date()
            ended = nil
        }
    }

    func stop() {
        lock.withLock {
            backfill?.cancel()
            backfill = nil
        }
    }

    /// Done or not, and its seconds so far.
    func progress() -> (done: Bool, seconds: Double) {
        lock.withLock {
            guard let started else { return (false, 0) }
            if ended == nil, backfill?.isFinished() == true { ended = Date() }
            return (ended != nil, (ended ?? Date()).timeIntervalSince(started))
        }
    }

    /// Keeps a found photo's or video's picture, so `searchPicture` can fetch it.
    func keep(_ message: FoundMessage, _ content: MessageType) {
        let picture: Picture?
        switch content {
        case .image(let c):
            picture = message.image.map { Picture(source: c.source, thumbnail: c.info?.thumbnailSource, name: $0.thumbnailName) }
        case .video(let c):
            picture = message.video.flatMap { $0.posterName.isEmpty ? nil : Picture(source: nil, thumbnail: c.info?.thumbnailSource, name: $0.posterName) }
        default:
            picture = nil
        }
        guard let picture else { return }
        lock.withLock { pictures[message.eventId] = picture }
    }

    fileprivate func picture(_ eventId: String) -> Picture? { lock.withLock { pictures[eventId] } }
}

extension MatrixAccount {
    /// Starts the sdk's search backfill: every chat paged back a week at a time, the newest
    /// week of every chat first, to 3 months; at the foreground's pace, a chat a second.
    func startSearchBackfill() {
        search.start(client.runSearchBackfill(strategy: .foreground))
    }

    public func searchIndexStatus() async -> SearchIndexStatus {
        let sizes = try? await client.getStoreSizes()
        let (done, seconds) = search.progress()
        return SearchIndexStatus(backfillDone: done, backfillSeconds: seconds, indexBytes: sizes?.searchIndex,
                                 eventCacheBytes: sizes?.eventCacheStore)
    }

    /// What `text` finds: chats by name (a part of a name is enough), then messages with every
    /// word, then the messages whose link has one of the words. `roomId` keeps one chat's
    /// messages only (no chats then): the index has no search in one chat, so it reads more of
    /// every chat's results. Messages come from the index: those this device has synced or paged
    /// back.
    public func search(_ text: String, in roomId: String? = nil, limit: Int = 40, timeout: TimeInterval = 30) async throws -> SearchResults {
        let words = SearchIndex.words(text)
        let chats = try await rooms(timeout: timeout)
        guard !words.isEmpty else { return SearchResults(chats: [], messages: [], links: []) }
        let found = try await messages(words, also: [], in: roomId, chats: chats, limit: limit, pages: roomId == nil ? 3 : 30) { _ in true }
        // a link with one of the words puts its message under links.
        let inLink = found.filter { m in m.links.contains { link in words.contains { SearchIndex.fold(link).contains($0) } } }
        let linked = Set(inLink.map(\.eventId))
        return SearchResults(chats: roomId == nil ? Self.chatsNamed(text, in: chats) : [],
                             messages: found.filter { !linked.contains($0.eventId) }, links: inLink)
    }

    /// One kind's messages across chats, the newest first; the words of `text` narrow them. A
    /// kind's messages are rare among the rest, so it reads more pages. The index knows a photo,
    /// video or file by its file name only (`indexWords`); in one chat, `chatKind` finds them by
    /// their type.
    public func search(kind: SearchKind, _ text: String = "", limit: Int = 60, timeout: TimeInterval = 30) async throws -> [FoundMessage] {
        let chats = try await rooms(timeout: timeout)
        return try await messages(SearchIndex.words(text), also: kind.indexWords, in: nil, chats: chats, limit: limit, pages: 15, keep: kind.has)
    }

    /// One kind's messages in one chat, the newest first, at most `limit`; the words of `text`
    /// narrow them, each the start of a word of the message's text, file name or link. They come
    /// from a timeline of the chat with only the kind's message types (photos and videos: the
    /// info page's), paged back once, from this device's cache and then the server, at most
    /// `pages` pages of 50 events: so a photo is found by its type, not its file name, and a
    /// voice message too, which the index does not know. A deleted chat's older messages went
    /// with it.
    public func chatKind(_ kind: SearchKind, _ text: String = "", roomId: String, limit: Int = 60, pages: Int = 20,
                         timeout: TimeInterval = 30) async throws -> [FoundMessage] {
        guard let chat = try await rooms(timeout: timeout).first(where: { $0.id == roomId }), !chat.isHidden else { return [] }
        let live = try await kindTimeline(kind, roomId, timeout: timeout)
        let me = (try? client.userId()) ?? ""
        let cut = await chatMarks().cleared[roomId] ?? 0
        let held: @Sendable () -> [(found: FoundMessage, content: MessageType)] = {
            live.items.read { items, _ in
                items.reversed().compactMap { item in
                    guard let event = item.asEvent(), event.timestamp > cut, case .eventId(let id) = event.eventOrTransactionId,
                          case .msgLike(let like) = event.content, case .message(let content) = like.kind,
                          let found = FoundMessage(content: event.content, eventId: id, sender: event.sender, profile: event.senderProfile,
                                                   timestamp: event.timestamp, chat: chat, me: me),
                          kind.has(found) else { return nil }
                    return (found, content.msgType)
                }
            }
        }
        do {
            try await search.paging(kind, roomId, limit) { try await live.pageBack(until: limit, pages: pages) { held().count } }.value
        } catch {
            search.forgetTimeline(kind, roomId)
            throw error
        }
        let words = SearchIndex.words(SearchIndex.fold(text))
        let kept = held().filter { Self.has(words, $0.found) }.prefix(limit)
        for (found, content) in kept { search.keep(found, content) }
        return kept.map(\.found)
    }

    /// Every word starts a word of the message's text, file name or links, without case or accents.
    static func has(_ words: [String], _ message: FoundMessage) -> Bool {
        guard !words.isEmpty else { return true }
        let own = SearchIndex.words(SearchIndex.fold(([message.body, message.file?.name ?? ""] + message.links).joined(separator: " ")))
        return words.allSatisfy { word in own.contains { $0.hasPrefix(word) } }
    }

    /// The chat's timeline of `kind`, opened once (photos and videos: the info page's).
    private func kindTimeline(_ kind: SearchKind, _ roomId: String, timeout: TimeInterval) async throws -> MediaTimeline {
        if kind == .images || kind == .videos { return try await mediaTimeline(roomId, timeout: timeout) }
        let opening = search.timeline(kind, roomId) {
            try await self.openTimeline(roomId, types: kind.messageTypes, prefix: "search-\(kind.rawValue)-", change: .search, timeout: timeout)
        }
        do {
            return try await opening.value
        } catch {
            search.forgetTimeline(kind, roomId)
            throw error
        }
    }

    /// The chats with these ids, in this order, but those deleted from this app or gone: the
    /// recent chats a search shows before any word.
    public func chats(_ ids: [String], timeout: TimeInterval = 30) async throws -> [RoomSummary] {
        let byId = Dictionary(try await rooms(timeout: timeout).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byId[$0] }.filter { !$0.isHidden }
    }

    /// The chats whose name has every word of `text`, the best first: the name starts with the
    /// text, then each word starts a word of the name, then the rest, each in the list's order.
    /// Case and accents do not count. A chat deleted from this app is left out.
    public static func chatsNamed(_ text: String, in chats: [RoomSummary]) -> [RoomSummary] {
        let whole = SearchIndex.fold(text).trimmingCharacters(in: .whitespacesAndNewlines)
        let words = whole.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return [] }
        let ranked = chats.enumerated().compactMap { i, chat -> (rank: Int, at: Int, chat: RoomSummary)? in
            let name = SearchIndex.fold(chat.name)
            guard !chat.isHidden, words.allSatisfy(name.contains) else { return nil }
            let nameWords = name.split { !$0.isLetter && !$0.isNumber }
            let starts = words.allSatisfy { w in nameWords.contains { $0.hasPrefix(w) } }
            return (name.hasPrefix(whole) ? 0 : (starts ? 1 : 2), i, chat)
        }
        return ranked.sorted { ($0.rank, $0.at) < ($1.rank, $1.at) }.map(\.chat)
    }

    /// A found photo's thumbnail or video's poster as a file in `directory`, under the name the
    /// chat gives it, so one downloaded for either shows in both.
    public func searchPicture(eventId: String, directory: URL, side: UInt64 = 800) async throws -> URL {
        guard let picture = search.picture(eventId) else { throw MatrixCoreError.noImage(eventId) }
        let file = directory.appendingPathComponent(picture.name)
        if FileManager.default.fileExists(atPath: file.path) { return file }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data: Data
        if let thumbnail = picture.thumbnail, let small = try? await client.getMediaContent(mediaSource: thumbnail) {
            data = small
        } else if let source = picture.source {
            do {
                data = try await client.getMediaThumbnail(mediaSource: source, width: side, height: side)
            } catch {
                data = try await client.getMediaContent(mediaSource: source)
            }
        } else {
            throw MatrixCoreError.noImage(eventId)
        }
        try data.write(to: file, options: .atomic)
        return file
    }

    /// Opens a chat at a found message: its timeline pages back until it holds the message (at
    /// most `limit` events, read from this device's cache first), then shows from a few messages
    /// before it. The message's id in the chat, or nil when it is further back: the chat then
    /// shows its newest messages.
    public func showMessage(roomId: String, eventId: String, limit: Int = 1000, timeout: TimeInterval = 30) async throws -> String? {
        let live = try await liveTimeline(roomId, limit: 20, timeout: timeout)
        let id = try await live.show(event: eventId, context: 5, limit: limit)
        // the messages it shows now were loaded before: no change of the timeline's says so.
        if id != nil { notify(.room(roomId)) }
        return id
    }

    /// The index's messages with every word and one of `also`, the newest first, that `keep`
    /// keeps, read page after page (20 a page) until `limit` are kept or `pages` are read. Those of
    /// chats deleted from this app, or not in the list, are left out.
    private func messages(_ words: [String], also: [String], in roomId: String?, chats: [RoomSummary], limit: Int, pages: Int,
                          keep: (FoundMessage) -> Bool) async throws -> [FoundMessage] {
        guard !words.isEmpty || !also.isEmpty else { return [] }
        let service = client.searchService()
        try await service.setQuery(query: SearchIndex.query(words, also: also))
        let byId = Dictionary(chats.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let me = (try? client.userId()) ?? ""
        var read = 1
        while true {
            let results = await Self.results(of: service)
            let found = results.compactMap { result -> FoundMessage? in
                guard case .message(let room, let message) = result, roomId == nil || room == roomId,
                      let chat = byId[room], !chat.isHidden,
                      let found = FoundMessage(message, chat: chat, me: me), keep(found) else { return nil }
                if case .msgLike(let like) = message.content, case .message(let content) = like.kind { search.keep(found, content.msgType) }
                return found
            }
            if found.count >= limit || read >= pages { return Array(found.prefix(limit)) }
            if case .idle(endReached: true) = service.paginationState() { return found }
            try await service.paginate()
            read += 1
        }
    }

    /// The results a search service holds now: a new subscription starts with all of them.
    private static func results(of service: SearchService) async -> [SearchServiceResult] {
        let collector = SearchResultsCollector()
        let handle = await service.subscribeToResults(listener: collector)
        handle.cancel()
        return collector.all
    }
}

extension TimelineItems {
    /// The id the chat gives the message with this event id, if the timeline holds it.
    func messageId(ofEvent eventId: String) -> String? {
        read { items, _ in
            items.first { item in
                if case .eventId(eventId)? = item.asEvent()?.eventOrTransactionId { return true }
                return false
            }?.uniqueId().id
        }
    }
}

extension FoundMessage {
    /// A search's message; nil for a result that is no message (a sticker, a poll).
    init?(_ result: MessageSearchResult, chat: RoomSummary, me: String) {
        self.init(content: result.content, eventId: result.eventId, sender: result.sender, profile: result.senderProfile,
                  timestamp: result.timestamp, chat: chat, me: me)
    }

    /// A message of the index or of a timeline; nil for one that is no message (a sticker, a poll).
    init?(content: TimelineItemContent, eventId: String, sender: String, profile: ProfileDetails, timestamp: UInt64,
          chat: RoomSummary, me: String) {
        guard case .msgLike(let like) = content, case .message(let message) = like.kind else { return nil }
        var body = message.body, kind = Kind.text
        var image: MessageImage?, video: MessageVideo?, file: MessageFile?, audio: MessageAudio?
        switch message.msgType {
        case .image(let content):
            (kind, body, image) = (.image, content.caption ?? "", MessageImage(content))
        case .video(let content):
            (kind, body, video) = (.video, content.caption ?? "", MessageVideo(content))
        case .file(let content):
            (kind, body, file) = (.file, content.caption ?? "", MessageFile(content))
        case .audio(let content):
            (kind, body, audio) = (.audio, content.caption ?? "", MessageAudio(content))
            file = MessageFile(name: content.filename, size: Int(content.info?.size ?? 0), mimetype: content.info?.mimetype ?? "")
        case .text, .notice, .emote:
            kind = .text
        default:
            kind = .other
        }
        var name = sender, picture = ""
        if case .ready(let shown, _, let url, _, _) = profile {
            if let shown, !shown.isEmpty { name = shown }
            picture = url ?? ""
        }
        self.init(chat: chat, eventId: eventId, sender: sender, senderName: name, isOwn: sender == me,
                  body: body, timestamp: timestamp, kind: kind, links: SearchIndex.links(in: body),
                  image: image, video: video, file: file, audio: audio, senderPicture: picture)
    }
}

/// A search service's results, kept current by applying its diffs.
private final class SearchResultsCollector: SearchServiceResultsListener, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [SearchServiceResult] = []

    var all: [SearchServiceResult] { lock.withLock { values } }

    func onUpdate(updates: [SearchServiceResultsUpdate]) {
        lock.withLock {
            for update in updates {
                switch update {
                case .append(let more): values += more
                case .clear: values = []
                case .pushFront(let value): values.insert(value, at: 0)
                case .pushBack(let value): values.append(value)
                case .popFront: if !values.isEmpty { values.removeFirst() }
                case .popBack: if !values.isEmpty { values.removeLast() }
                case .insert(let index, let value): values.insert(value, at: min(Int(index), values.count))
                case .set(let index, let value): if Int(index) < values.count { values[Int(index)] = value }
                case .remove(let index): if Int(index) < values.count { values.remove(at: Int(index)) }
                case .truncate(let length): values = Array(values.prefix(Int(length)))
                case .reset(let all): values = all
                }
            }
        }
    }
}
