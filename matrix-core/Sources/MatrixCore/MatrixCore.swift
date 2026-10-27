import Foundation
// a swift package build imports the sdk as a module; the exact app compiles
// these files into the same module as the sdk's bindings, so there is nothing to import.
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// The only code that calls matrix-rust-sdk. Its public API uses plain types,
/// so the app (Exact today, Expo as the fallback) never sees an sdk type.
public enum MatrixCore {
    /// The matrix-rust-sdk commit the linked library was built from.
    public static func sdkCommit() -> String {
        sdkGitSha()
    }
}

/// What the app keeps (in the Keychain) to sign in again without a password.
public struct SavedSession: Codable, Equatable, Sendable {
    public var userId: String
    public var deviceId: String
    public var homeserverUrl: String
    public var accessToken: String
    public var refreshToken: String?
    public var oauthData: String?
    public var nativeSlidingSync: Bool
}

public struct RoomSummary: Equatable, Sendable {
    public var id: String
    public var name: String
    public var isDirect: Bool
}

public struct Message: Equatable, Sendable {
    /// The event id, or the transaction id while a message is still being sent.
    public var id: String
    public var sender: String
    public var senderName: String
    public var body: String
    /// Milliseconds since 1970.
    public var timestamp: UInt64
    public var isOwn: Bool
}

public enum MatrixCoreError: Error, Equatable {
    case noRoom(String)
    case timedOut(String)
    case sendFailed(String)
}
