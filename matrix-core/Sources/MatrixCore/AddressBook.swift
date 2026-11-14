import Foundation

// the phone's contacts, linked to chats. the app reads the address book (matrixcore never asks
// the contacts framework) and hands it over as plain values. a bridge's contact list
// (`_matrix/provision/v3/contacts`) links each phone number to the bridge's user and its direct
// chat: a whatsapp chat's other person has a hidden id ("lid-…") with no phone number in it, so
// the number links only through the bridge.

/// a person from the phone's address book.
public struct BookContact: Equatable, Sendable {
    public var id: String
    public var name: String
    /// the numbers as the address book keeps them, in any format.
    public var phones: [String]

    public init(id: String, name: String, phones: [String]) {
        self.id = id
        self.name = name
        self.phones = phones
    }
}

/// a person the search found who has no chat in the list: from the address book, from a
/// bridge's contact list, or the phone number typed. choosing one starts a chat
/// through the app's existing network chooser.
public struct FoundPerson: Equatable, Sendable {
    /// "book:<id>", "bridge:<user id>" or "number:<digits>".
    public var id: String
    public var name: String
    public var accountId: String = ""
    public var identifier: String = ""
    /// what the row shows under the name: the number.
    public var detail: String
    /// the network its chat is on or would start on ("whatsapp"); "" when no bridge knows it.
    public var network: String
    /// its chat, when the bridge has one this account has not joined or has hidden; "" for none.
    public var room: String
    /// the numbers to start a chat with, the bridge's (international) first.
    public var phones: [String]
}

/// a person on a bridged network, from the bridge's contact list.
struct BridgePerson: Equatable, Sendable {
    var userId: String
    var identifier: String = ""
    var name: String
    var network: String
    var accountId: String
    /// its numbers as `tel:` identifiers give them ("+14155550101").
    var phones: [String]
    /// its direct chat; "" for none.
    var room: String
}

/// conservative number matching: exact digits and north american national forms.
enum PhoneNumber {
    /// the number's digits, and whether they begin with a country code ("+" or "00").
    static func parse(_ text: String) -> (digits: String, international: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isASCII).filter(\.isNumber)
        if trimmed.hasPrefix("+") { return (digits, true) }
        if digits.hasPrefix("00") { return (String(digits.dropFirst(2)), true) }
        return (digits, false)
    }

    /// the fewest digits accepted as a full phone number.
    static let shortest = 7

    /// full numbers match exactly; ten-digit national numbers also match their +1 form.
    static func same(_ a: String, _ b: String) -> Bool {
        let (x, y) = (parse(a), parse(b))
        if x.international && y.international { return x.digits.count >= shortest && x.digits == y.digits }
        if x.digits == y.digits { return x.digits.count >= shortest }
        // ten-digit north american national numbers have an unambiguous country code.
        let national = x.international ? y : x
        let global = x.international ? x : y
        return global.international && !national.international && national.digits.count == 10
            && global.digits == "1" + national.digits
    }

    /// where an index files a number: its last 7 digits; nil for a shorter one.
    static func key(_ text: String) -> String? {
        let digits = parse(text).digits
        return digits.count >= shortest ? String(digits.suffix(shortest)) : nil
    }

    /// text that is only a phone number: digits with spaces, "+", "-", ".", "(" and ")", and at
    /// least `least` digits.
    static func looksLikeNumber(_ text: String, least: Int = 4) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.allSatisfy({ $0.isASCII && ($0.isNumber || " +-.()".contains($0)) }) else { return false }
        return trimmed.filter(\.isNumber).count >= least
    }

    /// the number the bridges resolve: "+" and its digits when it has a country code; else its
    /// digits as the address book has them.
    static func dialable(_ text: String) -> String {
        let (digits, international) = parse(text)
        return international ? "+" + digits : text.filter(\.isASCII).filter(\.isNumber)
    }
}

/// the address book and the bridges' contacts, for one account.
final class ContactBook: @unchecked Sendable {
    /// how long a bridge's contact list is kept before it is asked again.
    static let freshness: TimeInterval = 600
    private let lock = NSLock()
    /// nil while the app has not connected the address book (settings' switch off).
    private var book: [BookContact]?
    private var people: [BridgePerson] = []
    private var peopleAt: Date?
    private var retryAfter: Date?
    private var fetching = false

    func set(_ contacts: [BookContact]?) {
        lock.withLock {
            book = contacts

        }
    }

    func snapshot() -> (book: [BookContact], people: [BridgePerson])? {
        lock.withLock { (book ?? [], people) }
    }

    /// whether the bridges' lists should be asked again; marks the asking begun.
    func startFetch(force: Bool) -> Bool {
        lock.withLock {
            guard !fetching else { return false }
            if !force, let retryAfter, Date() < retryAfter { return false }
            if !force, let at = peopleAt, Date().timeIntervalSince(at) < Self.freshness { return false }
            fetching = true
            return true
        }
    }

    /// the bridges' lists asked; false when nothing changed.
    @discardableResult
    func finishFetch(_ found: BridgePeople?) -> Bool {
        lock.withLock {
            fetching = false
            guard let found else { retryAfter = Date().addingTimeInterval(30); return false }
            retryAfter = nil
            peopleAt = Date()
            let retained = people.filter { !found.refreshed.contains($0.accountId) && (!found.complete || found.known.contains($0.accountId)) }
            let combined = found.people + retained
            let changed = combined != people
            people = combined
            return changed
        }
    }

    // mark: linking

    /// the name and numbers each direct chat's person has in the address book: by the bridge's
    /// direct chat, by the chat's other person, or by a number in that person's user id
    /// ("@whatsapp_14155550101:server"). a bridge's contact without an address book entry keeps
    /// the bridge's name for it, which whatsapp takes from the phone's own contacts.
    static func link(_ rooms: [RoomSummary], book: [BookContact], people: [BridgePerson]) -> [String: (name: String, phones: [String])] {
        let index = BookIndex(book)
        let byRoom = Dictionary(people.filter { !$0.room.isEmpty }.map { ($0.room, $0) }, uniquingKeysWith: { first, _ in first })
        let byUser = Dictionary(people.map { ($0.userId, $0) }, uniquingKeysWith: { first, _ in first })
        var linked: [String: (name: String, phones: [String])] = [:]
        for room in rooms where room.isOneToOne || byRoom[room.id] != nil {
            if let person = byRoom[room.id] ?? (room.counterpart.isEmpty ? nil : byUser[room.counterpart]) {
                let contact = person.phones.lazy.compactMap(index.contact).first
                let name = contact?.name ?? person.name
                if !name.isEmpty { linked[room.id] = (name, person.phones) }
            } else if let number = numberIn(userId: room.counterpart), let contact = index.contact(number), !contact.name.isEmpty {
                linked[room.id] = (contact.name, [number])
            }
        }
        return linked
    }

    /// the phone number in a bridge user's id ("@whatsapp_14155550101:server" is +14155550101);
    /// nil for an id with none ("@whatsapp_lid-…", a uuid).
    static func numberIn(userId: String) -> String? {
        guard userId.hasPrefix("@whatsapp_") || userId.hasPrefix("@signal_"), let colon = userId.firstIndex(of: ":") else { return nil }
        let local = userId[userId.index(after: userId.startIndex)..<colon]
        guard let underscore = local.lastIndex(of: "_") else { return nil }
        let digits = local[local.index(after: underscore)...]
        guard digits.count >= 8, digits.count <= 15, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return "+" + digits
    }

    // mark: searching

    /// the people `text` finds, by any part of a name or of a number: the address book's, then
    /// the bridges' without an address book entry; a person whose chat is in `chats` is that chat
    /// (`chatids`), not a person. a number typed that no one has is a person of its own, to start
    /// a chat with. `limit` people at most.
    static func find(_ text: String, book: [BookContact], people: [BridgePerson], chats: [RoomSummary],
                     limit: Int = 8) -> (people: [FoundPerson], chatIds: [String]) {
        let whole = SearchIndex.fold(text).trimmingCharacters(in: .whitespacesAndNewlines)
        let words = whole.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return ([], []) }
        let number = PhoneNumber.looksLikeNumber(text) ? PhoneNumber.parse(text).digits : nil
        func named(_ name: String) -> Int? {
            let folded = SearchIndex.fold(name)
            guard words.allSatisfy(folded.contains) else { return nil }
            let nameWords = folded.split { !$0.isLetter && !$0.isNumber }
            return folded.hasPrefix(whole) ? 0 : (words.allSatisfy { w in nameWords.contains { $0.hasPrefix(w) } } ? 1 : 2)
        }
        func dialed(_ phones: [String]) -> Bool {
            guard let number else { return false }
            return phones.contains { PhoneNumber.parse($0).digits.contains(number) || PhoneNumber.same($0, text) }
        }
        let visible = Dictionary(chats.filter { !$0.isHidden }.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let byUser = Dictionary(chats.filter { !$0.counterpart.isEmpty && !$0.isHidden }.map { ($0.counterpart, $0.id) },
                                uniquingKeysWith: { first, _ in first })
        func person(for phones: [String]) -> BridgePerson? {
            people.first { p in p.phones.contains { mine in phones.contains { PhoneNumber.same(mine, $0) } } }
        }
        func chat(of person: BridgePerson?) -> String? {
            guard let person else { return nil }
            if !person.room.isEmpty, visible[person.room] != nil { return person.room }
            return byUser[person.userId]
        }
        var ranked: [(rank: Int, at: Int, person: FoundPerson)] = []
        var chatIds: [String] = []
        var taken = Set<String>()
        for (i, contact) in book.enumerated() {
            guard let rank = named(contact.name) ?? (dialed(contact.phones) ? 1 : nil) else { continue }
            let matchingPhones = number == nil ? contact.phones : contact.phones.filter { dialed([$0]) }
            for (slot, phone) in (matchingPhones.isEmpty ? [""] : matchingPhones).enumerated() {
                let bridged = person(for: [phone])
                if let bridged { taken.insert(bridged.userId) }
                if let room = chat(of: bridged) ?? chats.first(where: {
                    !$0.isHidden && $0.phones.contains { PhoneNumber.same($0, phone) }
                })?.id {
                    if !chatIds.contains(room) { chatIds.append(room) }
                    continue
                }
                ranked.append((rank, i, FoundPerson(id: "book:" + contact.id + ":" + String(slot), name: contact.name,
                    detail: phone, network: bridged?.network ?? "", room: bridged?.room ?? "",
                    phones: phone.isEmpty ? [] : [phone])))
            }
        }
        for (i, bridged) in people.enumerated() where !taken.contains(bridged.userId) {
            guard let rank = named(bridged.name) ?? (dialed(bridged.phones) ? 1 : nil) else { continue }
            if let room = chat(of: bridged) {
                if !chatIds.contains(room) { chatIds.append(room) }
                continue
            }
            ranked.append((rank, book.count + i, FoundPerson(id: "bridge:" + bridged.userId, name: bridged.name, accountId: bridged.accountId, identifier: bridged.identifier.isEmpty ? bridged.userId : bridged.identifier,
                                                             detail: bridged.phones.first ?? "", network: bridged.network,
                                                             room: bridged.room, phones: bridged.phones)))
        }
        var found = ranked.sorted { ($0.rank, $0.at) < ($1.rank, $1.at) }.map(\.person)
        // a whole number no one has: start a chat with it.
        if let number, number.count >= PhoneNumber.shortest, chatIds.isEmpty, found.isEmpty {
            let typed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            found.insert(FoundPerson(id: "number:" + PhoneNumber.dialable(typed), name: typed, detail: "", network: "",
                                     room: "", phones: [PhoneNumber.dialable(typed)]), at: 0)
        }
        return (Array(found.prefix(limit)), chatIds)
    }
}

/// the address book filed by each number's last 7 digits.
struct BookIndex {
    private var byKey: [String: [(phone: String, contact: BookContact)]] = [:]

    init(_ book: [BookContact]) {
        for contact in book {
            for phone in contact.phones {
                if let key = PhoneNumber.key(phone) { byKey[key, default: []].append((phone, contact)) }
            }
        }
    }

    /// the contact with `phone`, when exactly one person has it.
    func contact(_ phone: String) -> BookContact? {
        guard let key = PhoneNumber.key(phone) else { return nil }
        let matches = (byKey[key] ?? []).filter { PhoneNumber.same($0.phone, phone) }
        let ids = Set(matches.map(\.contact.id))
        return ids.count == 1 ? matches.first?.contact : nil
    }
}

extension ConversationResolved {
    /// the bridge's contact as a person with numbers; nil for one with no user on matrix.
    func person(source: ConversationSource) -> BridgePerson? {
        let user = mxid.flatMap { $0.isEmpty ? nil : $0 } ?? source.account.id + ":" + id
        let phones = (identifiers ?? []).compactMap { $0.hasPrefix("tel:") ? String($0.dropFirst(4)) : nil }
        return BridgePerson(userId: user, identifier: mxid ?? id, name: name ?? "", network: source.account.network, accountId: source.account.id,
                            phones: phones, room: dm_room_mxid ?? "")
    }
}

struct BridgePeople {
    var people: [BridgePerson]
    var refreshed: Set<String>
    var known: Set<String>
    var complete: Bool
}

extension ConversationHTTP {
    /// every bridge login's contact list with numbers. a bridge without a list (501, 404) adds no
    /// one; nil when every login failed, so the people known before are kept.
    func people() async -> BridgePeople? {
        struct Contacts: Decodable { var contacts: [ConversationResolved] }
        let listing = await sources()
        guard listing.problem.isEmpty || !listing.items.isEmpty else { return nil }
        let sources = listing.items
        var found: [BridgePerson] = []
        var failed = 0
        var refreshed = Set<String>()
        for source in sources {
            do {
                found += try decode(Contacts.self, await bridge(source, "contacts")).contacts.compactMap { $0.person(source: source) }
                refreshed.insert(source.account.id)
            }
            catch ConversationError.http(let status) where status == 404 || status == 501 { refreshed.insert(source.account.id) }
            catch { failed += 1 }
        }
        return !sources.isEmpty && failed == sources.count ? nil : BridgePeople(people: found, refreshed: refreshed, known: Set(sources.map { $0.account.id }), complete: listing.problem.isEmpty)
    }
}

extension MatrixAccount {
    /// connects the phone's address book (nil disconnects it): direct chats with a contact show
    /// the contact's name, and search finds contacts. the book stays in memory only.
    public func setAddressBook(_ contacts: [BookContact]?) {
        contactBook.set(contacts)
        notify(.rooms)
        refreshPeople()
    }

    /// asks the bridges' contact lists again when they are older than 10 minutes (or `force`),
    /// in the background; the list hears of a change.
    func refreshPeople(force: Bool = false) {
        guard let saved = try? savedSession(), contactBook.startFetch(force: force) else { return }
        Task { [weak self] in
            let found = await ConversationHTTP(saved: saved).people()
            if self?.contactBook.finishFetch(found) == true { self?.notify(.rooms) }
        }
    }

    /// each direct chat named by the address book, with its person's numbers. a name the
    /// account gave the chat (`setcustomname`) still wins.
    func fillContactNames(_ rooms: inout [RoomSummary], custom: [String: String]) {
        guard let (book, people) = contactBook.snapshot() else { return }
        refreshPeople()
        let linked = ContactBook.link(rooms, book: book, people: people)
        for i in rooms.indices {
            guard let found = linked[rooms[i].id] else { continue }
            rooms[i].phones = found.phones
            if custom[rooms[i].id] == nil { rooms[i].name = found.name }
        }
    }

    /// the people `text` finds who have no chat in the list, and the chats of those who have one.
    public func people(_ text: String, in chats: [RoomSummary]) -> (people: [FoundPerson], chats: [RoomSummary]) {
        let snapshot = contactBook.snapshot() ?? (book: [], people: [])
        let found = ContactBook.find(text, book: snapshot.book, people: snapshot.people, chats: chats)
        let byId = Dictionary(chats.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return (found.people, found.chatIds.compactMap { byId[$0] })
    }

}
