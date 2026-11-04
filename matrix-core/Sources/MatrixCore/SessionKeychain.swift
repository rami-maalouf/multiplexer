import Foundation
import Security

/// What the Keychain holds for the signed-in account: its session, the name of its store
/// folder (a session without its store has lost its encryption keys), the key of its
/// message search index (`SearchIndex.newKey`; nil for a session kept before the index), and
/// the pusher this device set (`MatrixAccount.setPusher`), to replace when the push token
/// changes and to delete at Sign Out (nil for none).
public struct StoredSession: Codable, Equatable, Sendable {
    public var session: SavedSession
    public var store: String
    public var searchKey: String?
    public var pusherAppId: String?
    public var pushkey: String?
    /// nil is a session saved before shared stores, whose store was in the app's data.
    public var storeLocation: SessionStoreLocation?

    public init(session: SavedSession, store: String, searchKey: String? = nil, pusherAppId: String? = nil, pushkey: String? = nil,
                storeLocation: SessionStoreLocation? = nil) {
        self.session = session
        self.store = store
        self.searchKey = searchKey
        self.pusherAppId = pusherAppId
        self.pushkey = pushkey
        self.storeLocation = storeLocation
    }
}

/// Keeps one `StoredSession` in the Keychain, readable on this device only and after
/// the first unlock, so a notification extension can read it while the phone is locked.
/// `slot` names the item, so one service can keep more than one (the signed-in session,
/// and one that still has to be signed out on the server).
public struct SessionKeychain: Sendable {
    public var service: String
    public var slot: String
    /// The Keychain group the item is in: nil for the app's own default (its first
    /// `keychain-access-groups` entry, else its application identifier). The notification
    /// extension names the app's (`<team>.<app id>`), which its entitlements list too.
    public var accessGroup: String?

    public init(service: String, slot: String = "session", accessGroup: String? = nil) {
        self.service = service
        self.slot = slot
        self.accessGroup = accessGroup
    }

    private var item: [String: Any] {
        var item: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service,
                                   kSecAttrAccount as String: slot]
        if let accessGroup { item[kSecAttrAccessGroup as String] = accessGroup }
        return item
    }

    public func read() throws -> StoredSession? {
        var query = item
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var data: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &data)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = data as? Data else { throw MatrixCoreError.keychain(status) }
        return try JSONDecoder().decode(StoredSession.self, from: data)
    }

    public func write(_ stored: StoredSession) throws {
        let values: [String: Any] = [kSecValueData as String: try JSONEncoder().encode(stored),
                                     kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        // update in place: a failed write must leave the old session recoverable after a move.
        let updated = SecItemUpdate(item as CFDictionary, values as CFDictionary)
        if updated == errSecSuccess { return }
        guard updated == errSecItemNotFound else { throw MatrixCoreError.keychain(updated) }
        var add = item
        add.merge(values) { _, new in new }
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw MatrixCoreError.keychain(status) }
    }

    public func delete() throws {
        let status = SecItemDelete(item as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw MatrixCoreError.keychain(status) }
    }
}
