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
