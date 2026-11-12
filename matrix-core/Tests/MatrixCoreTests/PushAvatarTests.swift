@testable import MatrixCore
import XCTest

final class PushAvatarTests: XCTestCase {
    private let session = SavedSession(userId: "@test:example.org", deviceId: "test", homeserverUrl: "https://chat.example.org",
                                       accessToken: "test-secret", refreshToken: nil, oauthData: nil, nativeSlidingSync: true)

    func testAvatarUsesAuthenticatedHomeserverThumbnailWithShortDeadline() throws {
        let request = try XCTUnwrap(PushAvatar.request(session: session, avatar: "mxc://remote.example.org/picture"))
        XCTAssertEqual(request.url?.host, "chat.example.org")
        XCTAssertEqual(request.url?.path, "/_matrix/client/v1/media/thumbnail/remote.example.org/picture")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-secret")
        XCTAssertEqual(request.timeoutInterval, 2)
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(query.first { $0.name == "width" }?.value, "160")
        XCTAssertEqual(query.first { $0.name == "height" }?.value, "160")
    }

    func testMissingAndForeignURLsNeverBecomeAuthenticatedRequests() throws {
        for avatar in ["", "https://external.example.org/photo", "mxc://host/", "mxc://user:password@host/photo", "mxc://host/../photo", "mxc://host/photo?query=1"] {
            XCTAssertNil(try PushAvatar.request(session: session, avatar: avatar))
        }
        var insecure = session
        insecure.homeserverUrl = "http://chat.example.org"
        XCTAssertThrowsError(try PushAvatar.request(session: insecure, avatar: "mxc://host/photo"))
    }
    func testUnavailableInvalidAndOversizedPhotosLeaveNoAvatar() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PushAvatarProtocol.self]
        let transport = URLSession(configuration: configuration)
        defer { transport.invalidateAndCancel() }
        for (status, mime, size, expected) in [(200, "image/png", 12, true), (404, "image/png", 12, false),
                                               (200, "text/html", 12, false), (200, "image/png", 524_289, false)] {
            PushAvatarProtocol.response = (status, mime, size)
            let result = try await PushAvatar.data(session: session, avatar: "mxc://remote.example.org/photo", transport: transport)
            XCTAssertEqual(result != nil, expected)
        }
    }

}


private final class PushAvatarProtocol: URLProtocol {
    static var response = (200, "image/png", 12)
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, mime, size) = Self.response
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": mime])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(repeating: 1, count: size))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
