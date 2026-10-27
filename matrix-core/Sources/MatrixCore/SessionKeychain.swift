import Foundation
import Security

/// What the Keychain holds for the signed-in account: its session, and the name of
/// its store folder (a session without its store has lost its encryption keys).
public struct StoredSession: Codable, Equatable, Sendable {
    public var session: SavedSession
    public var store: String

    public init(session: SavedSession, store: String) {
        self.session = session
        self.store = store
    }
}

/// Keeps one `StoredSession` in the Keychain, readable on this device only and after
/// the first unlock, so a notification extension can read it while the phone is locked.
/// `slot` names the item, so one service can keep more than one (the signed-in session,
/// and one that still has to be signed out on the server).
public struct SessionKeychain: Sendable {
    public var service: String
    public var slot: String

    public init(service: String, slot: String = "session") {
        self.service = service
        self.slot = slot
    }

    private var item: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: slot]
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
        try delete()
        var add = item
        add[kSecValueData as String] = try JSONEncoder().encode(stored)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw MatrixCoreError.keychain(status) }
    }

    public func delete() throws {
        let status = SecItemDelete(item as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw MatrixCoreError.keychain(status) }
    }
}
