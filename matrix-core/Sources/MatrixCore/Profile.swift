import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// The signed-in account as others see it: its display name and picture.
public struct OwnProfile: Equatable, Sendable {
    public var userId: String
    /// The display name, or the user id's local part when none is set.
    public var displayName: String
    /// The picture's media url, or "" for none.
    public var avatarUrl: String
    /// The picture's file name under `pictureFile`'s directory ("" for none).
    public var avatarName: String { avatarUrl.isEmpty ? "" : "\(mediaKey(avatarUrl))-avatar.jpg" }
}

extension MatrixAccount {
    /// The account's own name and picture. Offline, the store's last known ones.
    public func ownProfile() async throws -> OwnProfile {
        let userId = try self.userId
        let name = (try? await client.displayName()) ?? ""
        let url: String?
        do { url = try await client.avatarUrl() } catch { url = try? await client.cachedAvatarUrl() }
        return OwnProfile(userId: userId, displayName: name.isEmpty ? Self.localPart(userId) : name, avatarUrl: url ?? "")
    }

    /// `@ana:example.org` → `ana`.
    static func localPart(_ userId: String) -> String {
        let trimmed = userId.hasPrefix("@") ? String(userId.dropFirst()) : userId
        return String(trimmed.split(separator: ":", maxSplits: 1).first ?? Substring(trimmed))
    }
}

/// What a bridge says identifies a person on their network, from their Matrix profile's
/// `com.beeper.bridge.identifiers` field (MSC4133 profile fields): `instagram:<username>`,
/// `linkedin:<id>`, `tel:+<number>`. The bridge writes it when its `ghost_extra_profile_info`
/// is on; [] for a profile without it, or with anything other than a list of strings there.
public enum NetworkIdentifiers {
    public static let field = "com.beeper.bridge.identifiers"

    /// A `GET /profile/{userId}` answer's identifiers.
    public static func parse(_ profile: Data) -> [String] {
        guard let object = try? JSONSerialization.jsonObject(with: profile) as? [String: Any],
              let list = object[field] as? [Any] else { return [] }
        return list.compactMap { $0 as? String }.filter { !$0.isEmpty }
    }
}

extension MatrixAccount {
    /// A person's network identifiers (`NetworkIdentifiers`), read from the server each time:
    /// a bridge can change them, and the SDK's profile has no custom fields. [] when the server
    /// has no profile for them (404) or will not show it (403).
    public func networkIdentifiers(userId: String) async throws -> [String] {
        let session = try savedSession()
        guard let base = URL(string: session.homeserverUrl) else { throw URLError(.badURL) }
        let url = base.appendingPathComponent("_matrix/client/v3/profile").appendingPathComponent(userId)
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        switch (response as? HTTPURLResponse)?.statusCode {
        case 200: return NetworkIdentifiers.parse(data)
        case 403, 404: return []
        default: throw URLError(.badServerResponse)
        }
    }
}
