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
    /// The file name of the room's picture for `MatrixAccount.avatarFile`; "" when it has none.
    public var avatarName: String = ""
    /// Messages after this account's read receipt.
    public var unreadCount: Int = 0
}

public struct Message: Equatable, Sendable {
    /// The timeline's id for the message: the same while it is sent and after.
    public var id: String
    public var sender: String
    public var senderName: String
    public var body: String
    /// Milliseconds since 1970.
    public var timestamp: UInt64
    public var isOwn: Bool
    public var sendState: SendState
    /// The picture of a photo message; nil for text. `body` is then its caption, or "".
    public var image: MessageImage?
    /// An encrypted message this device has no key for yet (`body` is ""). It turns into
    /// the message when the key comes: from the sender, or from the key backup (`recover`).
    public var waitingForKey: Bool = false
}

/// Whether the account keeps its message keys in a backup that a recovery key opens.
public enum RecoveryStatus: String, Sendable {
    /// This device can read the backup.
    case enabled
    /// The account has no recovery set up.
    case disabled
    /// The account has recovery, but this device cannot read it yet: it needs the recovery key.
    case incomplete
    case unknown
}

public struct MessageImage: Equatable, Sendable {
    /// In pixels; 0 when the sender did not say.
    public var width: Int
    public var height: Int
    /// File names for `MatrixAccount.imageFile`: the same for the same picture, so a
    /// downloaded file can be found again.
    public var thumbnailName: String
    public var fullName: String
}

/// Where a message is on its way to the server. Others' messages are `sent`.
public enum SendState: String, Sendable {
    case sending
    case sent
    /// The server refused it, or could not be reached: `MatrixAccount.retry` tries again.
    case failed
}

public enum MatrixCoreError: Error, Equatable {
    case noRoom(String)
    case timedOut(String)
    case sendFailed(String)
    /// The message is not a photo, or not in the open chat.
    case noImage(String)
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
