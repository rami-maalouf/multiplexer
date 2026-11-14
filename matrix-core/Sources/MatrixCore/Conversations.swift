import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

public struct ConversationAccount: Equatable, Sendable {
    public var id: String
    public var name: String
    public var network: String
}

public struct ConversationContact: Equatable, Sendable {
    public var id: String
    public var accountId: String
    public var name: String
    public var identifier: String
    public var network: String
    public var avatar: String
}

public struct ConversationListing<Item: Sendable>: Sendable {
    public var items: [Item]
    public var problem: String
}

enum ConversationError: LocalizedError {
    case untrustedEndpoint, invalidResponse, unknownAccount, invalidIdentifier, http(Int)
    case noBridgeAccount, severalBridgeAccounts, noDirectChat

    var errorDescription: String? {
        switch self {
        case .untrustedEndpoint: return "conversation source must use the homeserver's https origin without redirects"
        case .invalidResponse: return "conversation source returned an invalid response"
        case .unknownAccount: return "conversation account is no longer available"
        case .invalidIdentifier: return "enter a full matrix user id such as @user:server"
        case .http(let status): return "conversation source returned http \(status)"
        case .noBridgeAccount: return "None of your connected accounts can reach this person. Try again."
        case .severalBridgeAccounts: return "More than one of your accounts can reach this person. Start the chat from New Chat."
        case .noDirectChat: return "You have no chat with this person yet."
        }
    }
}

struct ConversationSource: Sendable {
    var base: URL
    var login: String
    var account: ConversationAccount
}

struct ConversationWhoami: Decodable {
    struct Network: Decodable { var displayname: String; var network_id: String }
    struct Login: Decodable {
        struct Profile: Decodable { var name: String? }
        var id: String
        var name: String
        var profile: Profile?
    }
    var network: Network
    var logins: [Login]

    func sources(base: URL) -> [ConversationSource] {
        logins.map { login in
            let label = [login.profile?.name, login.name].compactMap { $0 }.filter { !$0.isEmpty }
            let name = label.count > 1 && label[0] != label[1] ? "\(label[0]) (\(label[1]))" : (label.first ?? login.id)
            // json encodes the pair without ambiguities from separators in either id.
            let id = String(decoding: try! JSONEncoder().encode([base.absoluteString, login.id]), as: UTF8.self)
            return ConversationSource(base: base, login: login.id,
                                      account: ConversationAccount(id: id, name: "\(network.displayname): \(name)", network: network.network_id))
        }
    }
}

struct ConversationResolved: Decodable {
    var id: String
    var name: String?
    var avatar_url: String?
    var identifiers: [String]?
    var mxid: String?
    var dm_room_mxid: String?

    func contact(source: ConversationSource) -> ConversationContact {
        ConversationContact(id: source.account.id + ":" + id, accountId: source.account.id,
                            name: name.flatMap { $0.isEmpty ? nil : $0 } ?? identifiers?.first ?? id,
                            identifier: mxid ?? id, network: source.account.network, avatar: avatar_url ?? "")
    }
}

// neither discovery nor authenticated requests follow redirects, including same-origin ones.
final class ConversationRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

struct ConversationHTTP {
    private static let redirects = ConversationRedirects()
    private static let session = URLSession(configuration: .ephemeral, delegate: redirects, delegateQueue: nil)
    var saved: SavedSession
    var transport: URLSession = Self.session

    static func trusted(_ url: URL, home: URL) throws {
        guard url.scheme?.lowercased() == "https", home.scheme?.lowercased() == "https",
              url.host?.lowercased() == home.host?.lowercased(), url.host != nil,
              (url.port ?? 443) == (home.port ?? 443), url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil, home.user == nil, home.password == nil else {
            throw ConversationError.untrustedEndpoint
        }
    }

    static func isMatrixID(_ value: String) -> Bool {
        guard value.hasPrefix("@"), !value.contains(where: { $0.isWhitespace }),
              !value.contains("/"), !value.contains("?"), !value.contains("#") else { return false }
        let parts = value.dropFirst().split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && !parts[1].isEmpty
    }

    func request(_ url: URL, method: String = "GET", query: [URLQueryItem] = [], body: [String: String]? = nil,
                 authenticated: Bool = true, missingIsEmpty: Bool = false) async throws -> Data {
        guard let home = URL(string: saved.homeserverUrl) else { throw ConversationError.untrustedEndpoint }
        try Self.trusted(url, home: home)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!, timeoutInterval: 20)
        request.httpMethod = method
        if authenticated { request.setValue("Bearer \(saved.accessToken)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await transport.data(for: request) }
        catch is CancellationError { throw CancellationError() }
        catch { throw ConversationError.invalidResponse }
        guard let response = response as? HTTPURLResponse else { throw ConversationError.invalidResponse }
        if response.statusCode == 404 && missingIsEmpty { return Data("{}".utf8) }
        guard (200..<300).contains(response.statusCode) else { throw ConversationError.http(response.statusCode) }
        return data
    }

    func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw ConversationError.invalidResponse }
    }

    func accounts() async throws -> ConversationListing<ConversationAccount> {
        let available = await sources()
        return ConversationListing(items: [ConversationAccount(id: "matrix", name: "matrix: \(saved.userId)", network: "matrix")]
            + available.items.map(\.account), problem: available.problem)
    }

    func sources() async -> ConversationListing<ConversationSource> {
        struct Discovery: Decodable {
            var bridges: [String]?
            enum CodingKeys: String, CodingKey { case bridges = "fi.mau.bridges" }
        }
        var sources: [ConversationSource] = []
        var problem = ""
        let home: URL
        let discovery: Discovery
        do {
            guard let url = URL(string: saved.homeserverUrl), var root = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw ConversationError.untrustedEndpoint
            }
            home = url
            root.path = "/.well-known/matrix/mautrix"
            discovery = try decode(Discovery.self, await request(root.url!, authenticated: false, missingIsEmpty: true))
        } catch {
            return ConversationListing(items: [], problem: "Could not discover connected accounts. Matrix is still available. Try again.")
        }
        for value in Set(discovery.bridges ?? []).sorted() {
            do {
                guard let base = URL(string: value) else { throw ConversationError.untrustedEndpoint }
                try Self.trusted(base, home: home)
                let who = try decode(ConversationWhoami.self, await request(endpoint(base, "whoami"),
                    query: [URLQueryItem(name: "user_id", value: saved.userId)]))
                sources += who.sources(base: base)
            } catch {
                problem = "Some connected accounts are unavailable. Available accounts are shown. Try again."
            }
        }
        return ConversationListing(items: sources, problem: problem)
    }

    func endpoint(_ base: URL, _ operation: String, identifier: String? = nil) -> URL {
        var url = base.appendingPathComponent("_matrix/provision/v3").appendingPathComponent(operation)
        if let identifier {
            // encode a remote identifier as one path segment, even when it contains a slash.
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
            components.percentEncodedPath += "/" + identifier.addingPercentEncoding(withAllowedCharacters: allowed)!
            url = components.url!
        }
        return url
    }

    func bridge(_ source: ConversationSource, _ operation: String, identifier: String? = nil,
                method: String = "GET", body: [String: String]? = nil) async throws -> Data {
        try await request(endpoint(source.base, operation, identifier: identifier), method: method,
                          query: [URLQueryItem(name: "login_id", value: source.login),
                                  URLQueryItem(name: "user_id", value: saved.userId)], body: body)
    }

    func contacts(_ source: ConversationSource, query: String) async throws -> [ConversationContact] {
        struct Contacts: Decodable { var contacts: [ConversationResolved] }
        struct Search: Decodable { var results: [ConversationResolved] }
        var found: [ConversationResolved] = []
        var contactsUnsupported = false
        do { found = try decode(Contacts.self, await bridge(source, "contacts")).contacts }
        catch ConversationError.http(501) { contactsUnsupported = true }
        if !query.isEmpty {
            found = found.filter { contact in
                ([contact.id, contact.name ?? ""] + (contact.identifiers ?? [])).contains {
                    $0.localizedStandardContains(query)
                }
            }
            do {
                let searched = try decode(Search.self, await bridge(source, "search_users", method: "POST", body: ["query": query])).results
                found += searched
            }
            catch ConversationError.http(501) { }
            if found.isEmpty {
                do { found.append(try decode(ConversationResolved.self, await bridge(source, "resolve_identifier", identifier: query))) }
                catch ConversationError.http(404) { }
            }
        } else if contactsUnsupported { throw ConversationError.http(501) }
        var seen = Set<String>()
        return found.filter { seen.insert($0.id).inserted }.map { $0.contact(source: source) }
    }

    func contactListing(accountId: String, query: String, matrix: ConversationListing<ConversationContact>) async throws -> ConversationListing<ConversationContact> {
        let available = await sources()
        let selected = available.items.filter { accountId.isEmpty || $0.account.id == accountId }
        guard accountId.isEmpty || !selected.isEmpty else { throw ConversationError.unknownAccount }
        var result = matrix
        var problems = [matrix.problem, available.problem].filter { !$0.isEmpty }
        for source in selected {
            do { result.items += try await contacts(source, query: query) }
            catch {
                if !accountId.isEmpty { throw error }
                problems.append("Could not load \(source.account.name). Other available contacts are shown. Try again.")
            }
        }
        result.problem = problems.joined(separator: " ")
        return result
    }

    func start(_ source: ConversationSource, identifier: String) async throws -> String {
        let resolved = try decode(ConversationResolved.self, await bridge(source, "resolve_identifier", identifier: identifier))
        if let room = resolved.dm_room_mxid, !room.isEmpty { return room }
        let created = try decode(ConversationResolved.self, await bridge(source, "create_dm", identifier: resolved.mxid ?? identifier, method: "POST"))
        guard let room = created.dm_room_mxid, !room.isEmpty else { throw ConversationError.invalidResponse }
        return room
    }

    /// The bridges (whoami's `network_id`) that may hold a person of this network (`RoomNetwork`):
    /// the Meta bridge names itself "facebook" for Instagram as for Messenger.
    static func networkIDs(for network: String) -> Set<String> {
        switch network {
        case "instagram": return ["instagram", "facebook"]
        case "messenger": return ["messenger", "facebook"]
        default: return [network]
        }
    }

    /// A direct chat with a bridge's person, by their Matrix id (a ghost: `@instagram_123:server`).
    /// Each login of a bridge of their network is asked, read only, whether the person is its own
    /// (mautrix's `resolve_identifier` takes a ghost's id and answers its `mxid`). A chat is made
    /// only through the one login that says so; two such logins could each send, so neither does.
    /// `create` false finds a chat only, and makes none.
    func startWithGhost(_ userId: String, network: String, sources: [ConversationSource], create: Bool = true) async throws -> String {
        let ids = Self.networkIDs(for: network)
        var owners: [ConversationSource] = []
        for source in sources where ids.contains(source.account.network) {
            let resolved: ConversationResolved
            do { resolved = try decode(ConversationResolved.self, await bridge(source, "resolve_identifier", identifier: userId)) }
            catch is CancellationError { throw CancellationError() }
            catch { continue }
            guard resolved.mxid == userId else { continue }
            if let room = resolved.dm_room_mxid, !room.isEmpty { return room }
            owners.append(source)
        }
        guard let owner = owners.first else { throw ConversationError.noBridgeAccount }
        guard owners.count == 1 else { throw ConversationError.severalBridgeAccounts }
        guard create else { throw ConversationError.noDirectChat }
        let created = try decode(ConversationResolved.self, await bridge(owner, "create_dm", identifier: userId, method: "POST"))
        guard let room = created.dm_room_mxid, !room.isEmpty else { throw ConversationError.invalidResponse }
        return room
    }

    func matrixURL(_ path: [String]) throws -> URL {
        guard var url = URL(string: saved.homeserverUrl) else { throw ConversationError.untrustedEndpoint }
        url.appendPathComponent("_matrix/client/v3")
        for part in path { url.appendPathComponent(part) }
        return url
    }

    func directRooms() async throws -> [String: [String]] {
        let data = try await request(matrixURL(["user", saved.userId, "account_data", "m.direct"]), missingIsEmpty: true)
        return try decode([String: [String]].self, data)
    }
}

extension MatrixAccount {
    public func conversationAccounts() async throws -> ConversationListing<ConversationAccount> {
        try await ConversationHTTP(saved: savedSession()).accounts()
    }

    public func conversationContacts(accountId: String, query: String) async throws -> ConversationListing<ConversationContact> {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let http = ConversationHTTP(saved: try savedSession())
        var result = ConversationListing<ConversationContact>(items: [], problem: "")
        if accountId.isEmpty || accountId == "matrix" {
            if !query.isEmpty {
                // a full id remains selectable when the directory excludes it.
                if ConversationHTTP.isMatrixID(query) {
                    result.items.append(ConversationContact(id: "matrix:" + query, accountId: "matrix", name: query,
                                                      identifier: query, network: "matrix", avatar: ""))
                } else {
                    do {
                        let found = try await client.searchUsers(searchTerm: query, limit: 100)
                        result.items += found.results.map {
                            ConversationContact(id: "matrix:" + $0.userId, accountId: "matrix", name: $0.displayName ?? $0.userId,
                                                identifier: $0.userId, network: "matrix", avatar: $0.avatarUrl ?? "")
                        }
                    } catch {
                        if accountId == "matrix" { throw error }
                        result.problem = "Could not search Matrix. Other available contacts are shown. Try again."
                    }
                }
            }
            if accountId == "matrix" || ConversationHTTP.isMatrixID(query) { return result }
        }
        return try await http.contactListing(accountId: accountId, query: query, matrix: result)
    }

    public func startConversation(accountId: String, identifier: String) async throws -> String {
        let http = ConversationHTTP(saved: try savedSession())
        if accountId == "matrix" {
            guard ConversationHTTP.isMatrixID(identifier) else { throw ConversationError.invalidIdentifier }
            // read the server's m.direct so an immediate second start also reuses a new room.
            let direct = try await http.directRooms()
            struct Joined: Decodable { var joined_rooms: [String] }
            let joined = Set(try http.decode(Joined.self, await http.request(http.matrixURL(["joined_rooms"]))).joined_rooms)
            if let room = direct[identifier]?.first(where: { joined.contains($0) }) { return room }
            if let room = try client.getDmRooms(userId: identifier).first(where: { $0.membership() == .joined }) { return room.id() }
            let room = try await client.createRoom(request: CreateRoomParameters(name: nil, isEncrypted: true, isDirect: true,
                                                                                visibility: .private, preset: .trustedPrivateChat,
                                                                                invite: identifier == http.saved.userId ? [] : [identifier]))
            // the sdk normally writes m.direct for isDirect. merge a fresh server copy to
            // preserve other recipients, and ensure the new room is indexed before returning.
            let current = try await http.directRooms()
            var updated = current
            // a new device's sdk cache may predate the server's existing mappings.
            for (person, rooms) in direct {
                for previous in rooms where !(updated[person] ?? []).contains(previous) {
                    updated[person, default: []].append(previous)
                }
            }
            if !(updated[identifier] ?? []).contains(room) { updated[identifier, default: []].append(room) }
            if updated != current {
                let content = String(decoding: try JSONEncoder().encode(updated), as: UTF8.self)
                try await client.setAccountData(eventType: "m.direct", content: content)
            }
            return room
        }
        guard let source = await http.sources().items.first(where: { $0.account.id == accountId }) else {
            throw ConversationError.unknownAccount
        }
        return try await http.start(source, identifier: identifier)
    }

    /// The direct chat with a person met in a chat (a member's page, "Message"), on their own
    /// network: a Matrix user's as `startConversation` finds or makes it; a bridge's person's
    /// (a ghost of a bridge on this server) is the joined chat `m.direct` names for them, else
    /// the one their bridge opens (`startWithGhost`). Returns the room's id. `create` false only
    /// finds an existing chat (`noDirectChat` when there is none), and so changes nothing.
    public func directChat(with userId: String, create: Bool = true) async throws -> String {
        let http = ConversationHTTP(saved: try savedSession())
        guard ConversationHTTP.isMatrixID(userId), userId != http.saved.userId else { throw ConversationError.invalidIdentifier }
        // a bridge marks its chats with one person in m.direct (`sync_direct_chat_list`), as a
        // Matrix client marks its own.
        struct Joined: Decodable { var joined_rooms: [String] }
        let joined = Set(try http.decode(Joined.self, await http.request(http.matrixURL(["joined_rooms"]))).joined_rooms)
        if let room = try await http.directRooms()[userId]?.first(where: { joined.contains($0) }) { return room }
        if let room = try client.getDmRooms(userId: userId).first(where: { $0.membership() == .joined }) { return room.id() }
        let server = { (id: String) in id.split(separator: ":", maxSplits: 1).dropFirst().first.map(String.init) ?? "" }
        guard let network = RoomNetwork.network(ofBridgeUser: userId), server(userId) == server(http.saved.userId) else {
            guard create else { throw ConversationError.noDirectChat }
            return try await startConversation(accountId: "matrix", identifier: userId)
        }
        return try await http.startWithGhost(userId, network: network, sources: await http.sources().items, create: create)
    }
}
