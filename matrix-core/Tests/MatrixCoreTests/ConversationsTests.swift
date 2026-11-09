@testable import MatrixCore
import XCTest

final class ConversationsTests: XCTestCase {
    func testDiscoveryRejectsForeignInsecureAndCredentialedEndpoints() throws {
        let home = URL(string: "https://chat.example.org")!
        XCTAssertNoThrow(try ConversationHTTP.trusted(URL(string: "https://chat.example.org/bridges/one")!, home: home))
        for value in ["https://evil.example.org/bridge", "http://chat.example.org/bridge", "https://user:pass@chat.example.org/bridge", "https://chat.example.org:444/bridge", "https://chat.example.org/bridge?token=secret", "https://chat.example.org/bridge#fragment"] {
            XCTAssertThrowsError(try ConversationHTTP.trusted(URL(string: value)!, home: home))
        }
    }

    func testWhoamiLabelsEachLoginAndContactUsesRemoteIDForStartingChat() throws {
        let data = Data(#"{"network":{"displayname":"whatsapp","network_id":"whatsapp"},"logins":[{"id":"123","name":"+123","profile":{"name":"alice"}}]}"#.utf8)
        let bridge = URL(string: "https://chat.example.org/bridges/wa")!
        let sources = try JSONDecoder().decode(ConversationWhoami.self, from: data).sources(base: bridge)
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources[0].account.name, "whatsapp: alice (+123)")
        XCTAssertEqual(sources[0].account.network, "whatsapp")
        let contact = try JSONDecoder().decode(ConversationResolved.self, from: Data(#"{"id":"remote/123","name":"bob","identifiers":["tel:+123"],"avatar_url":"mxc://example.org/avatar","dm_room_mxid":"!dm:example.org"}"#.utf8))
        let row = contact.contact(source: sources[0])
        XCTAssertEqual(row.identifier, "remote/123")
        XCTAssertEqual(row.name, "bob")
        XCTAssertEqual(row.avatar, "mxc://example.org/avatar")
        XCTAssertEqual(row.accountId, sources[0].account.id)
        XCTAssertEqual(contact.dm_room_mxid, "!dm:example.org")
    }

    func testMatrixIdentifierCanBeSelectedWithoutDirectoryResults() {
        XCTAssertTrue(ConversationHTTP.isMatrixID("@alice:example.org"))
        XCTAssertFalse(ConversationHTTP.isMatrixID("alice"))
        XCTAssertFalse(ConversationHTTP.isMatrixID("@alice:"))
        XCTAssertFalse(ConversationHTTP.isMatrixID("@alice:example.org/path"))
    }

    func testHTTPFailureNeverIncludesResponseBodyOrToken() {
        let error = ConversationError.http(501)
        XCTAssertEqual(error.localizedDescription, "conversation source returned http 501")
    }

    func testIdentifierNotFoundIsAnEmptySearch() async throws {
        let http = http([
            ("contacts", 200, #"{"contacts":[]}"#),
            ("search_users", 501, #"{}"#),
            ("resolve_identifier", 404, #"{"errcode":"M_NOT_FOUND"}"#),
        ])
        let rows = try await http.contacts(source(), query: "nobody")
        XCTAssertTrue(rows.isEmpty)
    }

    func testDiscoveryFailurePreservesMatrixAccount() async throws {
        let http = http([("mautrix", 500, #"{}"#)])
        let accounts = try await http.accounts()
        XCTAssertEqual(accounts.items.map(\.id), ["matrix"])
        XCTAssertFalse(accounts.problem.isEmpty)
    }

    func testAllAccountsRetainsMatrixAndHealthyBridgeWhenAnotherFails() async throws {
        let http = http([
            ("mautrix", 200, #"{"fi.mau.bridges":["https://chat.example.org/a","https://chat.example.org/b"]}"#),
            ("whoami", 200, #"{"network":{"displayname":"signal","network_id":"signal"},"logins":[{"id":"login/+1","name":"a"}]}"#),
            ("whoami", 200, #"{"network":{"displayname":"whatsapp","network_id":"whatsapp"},"logins":[{"id":"login/+1","name":"b"}]}"#),
            ("contacts", 500, #"{}"#),
            ("contacts", 200, #"{"contacts":[{"id":"bob","name":"Bob"}]}"#),
        ])
        let matrix = ConversationContact(id: "matrix:bob", accountId: "matrix", name: "Bob", identifier: "@bob:example.org", network: "matrix", avatar: "")
        let found = try await http.contactListing(accountId: "", query: "", matrix: ConversationListing(items: [matrix], problem: ""))
        XCTAssertEqual(found.items.map(\.network), ["matrix", "whatsapp"])
        XCTAssertTrue(found.problem.contains("signal"))
    }

    func testSelectedAccountFailureRemainsAnError() async throws {
        let http = http([
            ("mautrix", 200, #"{"fi.mau.bridges":["https://chat.example.org/bridge"]}"#),
            ("whoami", 200, #"{"network":{"displayname":"signal","network_id":"signal"},"logins":[{"id":"login/+1","name":"a"}]}"#),
            ("contacts", 500, #"{}"#),
        ])
        let id = String(decoding: try JSONEncoder().encode(["https://chat.example.org/bridge", "login/+1"]), as: UTF8.self)
        do {
            _ = try await http.contactListing(accountId: id, query: "", matrix: ConversationListing(items: [], problem: ""))
            XCTFail("selected source failure was hidden")
        } catch ConversationError.http(500) { }
    }
    func testUnknownPhoneResolvesBeforeSelectionWithoutCreatingChat() async throws {
        let http = http([
            ("contacts", 200, #"{"contacts":[]}"#),
            ("search_users", 501, #"{"error":"unsupported"}"#),
            ("resolve_identifier", 200, #"{"id":"123","name":"bob","identifiers":["tel:+123"]}"#),
        ])
        let rows = try await http.contacts(source(), query: "+123")
        XCTAssertEqual(rows.map(\.identifier), ["123"])
        XCTAssertEqual(rows.map(\.name), ["bob"])
        XCTAssertEqual(ConversationProtocol.paths().count, 3)
        XCTAssertFalse(ConversationProtocol.paths().contains { $0.contains("create_dm") })
    }

    func testEmptyRemoteSearchResolvesUsernameAndReusesBridgeRoom() async throws {
        let http = http([
            ("contacts", 200, #"{"contacts":[]}"#),
            ("search_users", 200, #"{"results":[]}"#),
            ("resolve_identifier", 200, #"{"id":"bob","name":"bob"}"#),
            ("resolve_identifier", 200, #"{"id":"bob","dm_room_mxid":"!existing:example.org"}"#),
        ])
        let rows = try await http.contacts(source(), query: "bob")
        let room = try await http.start(source(), identifier: XCTUnwrap(rows.first).identifier)
        XCTAssertEqual(room, "!existing:example.org")
        XCTAssertFalse(ConversationProtocol.paths().contains { $0.contains("create_dm") })
    }

    func testBridgeCreatesOnlyOnExplicitStartAndEncodesRemoteIdentifier() async throws {
        let http = http([
            ("resolve_identifier", 200, #"{"id":"remote/123"}"#),
            ("create_dm", 200, #"{"id":"remote/123","dm_room_mxid":"!new:example.org"}"#),
        ])
        let room = try await http.start(source(), identifier: "remote/123")
        XCTAssertEqual(room, "!new:example.org")
        XCTAssertTrue(ConversationProtocol.paths().allSatisfy { $0.contains("remote%2F123") })
    }

    func testDiscoveryRejectsForeignOriginBeforeSendingBearer() async throws {
        let http = http([("mautrix", 200, #"{"fi.mau.bridges":["https://foreign.example.org/bridge"]}"#)])
        let sources = await http.sources()
        XCTAssertTrue(sources.items.isEmpty)
        XCTAssertFalse(sources.problem.isEmpty)
        XCTAssertEqual(ConversationProtocol.paths().count, 1)
    }

    func testUnauthorizedDiscoveredBridgeDoesNotHideOtherAvailableAccounts() async throws {
        let http = http([
            ("mautrix", 200, #"{"fi.mau.bridges":["https://chat.example.org/a-denied","https://chat.example.org/b-available"]}"#),
            ("whoami", 401, #"{"error":"not authorized"}"#),
            ("whoami", 200, #"{"network":{"displayname":"signal","network_id":"signal"},"logins":[{"id":"login","name":"alice"}]}"#),
        ])
        let accounts = try await http.accounts()
        XCTAssertEqual(accounts.items.map(\.network), ["matrix", "signal"])
        XCTAssertEqual(accounts.items.first?.id, "matrix")
        XCTAssertFalse(accounts.problem.isEmpty)
        XCTAssertEqual(ConversationProtocol.paths().count, 3)
    }

    func testAllDiscoveredBridgesUnauthorizedStillReturnsAnAvailableSourceList() async throws {
        let http = http([
            ("mautrix", 200, #"{"fi.mau.bridges":["https://chat.example.org/denied"]}"#),
            ("whoami", 401, #"{"error":"not authorized"}"#),
        ])
        let accounts = try await http.accounts()
        XCTAssertEqual(accounts.items.map(\.id), ["matrix"])
    }

    func testRedirectDelegateRefusesSameOriginAndForeignRedirects() {
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let original = URL(string: "https://chat.example.org/bridge")!
        let task = session.dataTask(with: original)
        let response = HTTPURLResponse(url: original, statusCode: 302, httpVersion: nil, headerFields: nil)!
        for destination in ["https://chat.example.org/other", "https://foreign.example.org/bridge"] {
            ConversationRedirects().urlSession(session, task: task, willPerformHTTPRedirection: response,
                newRequest: URLRequest(url: URL(string: destination)!)) { followed in
                    XCTAssertNil(followed)
                }
        }
    }

    private func source() -> ConversationSource {
        ConversationSource(base: URL(string: "https://chat.example.org/bridge")!, login: "login/+1",
                           account: ConversationAccount(id: "wa", name: "whatsapp", network: "whatsapp"))
    }

    private func http(_ replies: [(String, Int, String)]) -> ConversationHTTP {
        ConversationProtocol.configure(replies)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ConversationProtocol.self]
        let transport = URLSession(configuration: config, delegate: ConversationRedirects(), delegateQueue: nil)
        addTeardownBlock { transport.invalidateAndCancel() }
        return ConversationHTTP(saved: SavedSession(userId: "@test:example.org", deviceId: "test",
                                                    homeserverUrl: "https://chat.example.org", accessToken: "fixture-token",
                                                    nativeSlidingSync: true), transport: transport)
    }

}


private final class ConversationProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var replies: [(String, Int, String)] = []
    private static var requests: [String] = []

    static func configure(_ values: [(String, Int, String)]) {
        lock.withLock { replies = values; requests = [] }
    }
    static func paths() -> [String] { lock.withLock { requests } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        let reply: (String, Int, String)? = Self.lock.withLock {
            Self.requests.append(request.url!.absoluteString)
            return Self.replies.isEmpty ? nil : Self.replies.removeFirst()
        }
        guard let reply else {
            XCTFail("unexpected conversation request")
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        XCTAssertTrue(request.url!.path.contains(reply.0))
        if reply.0 == "mautrix" { XCTAssertNil(request.value(forHTTPHeaderField: "Authorization")) }
        else {
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-token")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            if reply.0 != "whoami" {
                XCTAssertEqual(query?.first(where: { $0.name == "login_id" })?.value, "login/+1")
            }
            XCTAssertEqual(query?.first(where: { $0.name == "user_id" })?.value, "@test:example.org")
            XCTAssertEqual(request.httpMethod, ["search_users", "create_dm"].contains(reply.0) ? "POST" : "GET")
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: reply.1, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(reply.2.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
