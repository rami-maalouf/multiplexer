import Foundation

// optional notification thumbnails use a separate short-lived request, after text is ready.
// only the homeserver sees the bearer token; media servers are addressed through its proxy.
enum PushAvatar {
    private static let transport: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 2
        return URLSession(configuration: configuration, delegate: ConversationRedirects(), delegateQueue: nil)
    }()

    static func request(session: SavedSession, avatar: String) throws -> URLRequest? {
        guard let media = URLComponents(string: avatar), media.scheme == "mxc", let host = media.host, !host.isEmpty,
              media.user == nil, media.password == nil, media.query == nil, media.fragment == nil else { return nil }
        let id = String(media.path.dropFirst())
        guard !id.isEmpty, !id.contains("/"), id != ".", id != ".." else { return nil }
        guard let home = URL(string: session.homeserverUrl) else { throw ConversationError.untrustedEndpoint }
        let server = host + (media.port.map { ":\($0)" } ?? "")
        let url = home.appendingPathComponent("_matrix/client/v1/media/thumbnail")
            .appendingPathComponent(server).appendingPathComponent(id)
        try ConversationHTTP.trusted(url, home: home)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "width", value: "160"), URLQueryItem(name: "height", value: "160"),
                                URLQueryItem(name: "method", value: "crop"), URLQueryItem(name: "animated", value: "false"),
                                URLQueryItem(name: "timeout_ms", value: "1500")]
        var request = URLRequest(url: components.url!, timeoutInterval: 2)
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    static func data(session: SavedSession, avatar: String, transport: URLSession = Self.transport) async throws -> Data? {
        guard let request = try request(session: session, avatar: avatar) else { return nil }
        let (bytes, response) = try await transport.bytes(for: request)
        defer { bytes.task.cancel() }
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              response.mimeType?.hasPrefix("image/") == true else { return nil }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 512 * 1024 else { return nil }
            data.append(byte)
        }
        return data.isEmpty ? nil : data
    }
}

extension MatrixPush {
    /// a sender's small static thumbnail; missing, slow or unavailable photos leave the alert intact.
    public static func senderAvatar(session: SavedSession, url: String) async -> Data? {
        try? await PushAvatar.data(session: session, avatar: url)
    }
}
