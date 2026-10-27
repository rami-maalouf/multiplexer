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

/// What changed, for `MatrixAccount.onChange`.
public enum MatrixChange: Hashable, Sendable {
    /// A room came or went, or its name, last message or time changed.
    case rooms
    /// The messages of an open chat changed.
    case room(String)
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
    /// The newest message as one line ("" when the room has none): its text, or its kind ("Photo").
    public var lastMessage: String
    public var lastSenderName: String
    public var lastIsOwn: Bool
    /// Milliseconds since 1970; 0 when the room has no message.
    public var lastTimestamp: UInt64
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
    /// A Keychain call failed with this `OSStatus`.
    case keychain(Int32)
}

/// Why `MatrixAccount.signIn` failed.
public enum SignInError: Error, Equatable {
    /// The server refused the user name and password.
    case wrongPassword
    /// No Matrix server answered at that name or address.
    case serverNotFound
    /// The server has no native sliding sync, which the sdk needs.
    case serverNotSupported
    /// Too many tries: the server asks the client to wait.
    case rateLimited
    /// Anything else, in the sdk's words.
    case other(String)
}
