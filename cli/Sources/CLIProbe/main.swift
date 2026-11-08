import Foundation
import MatrixCore
import Security
import Darwin

signal(SIGPIPE, SIG_IGN)

// private stdin/stdout protocol for the live test runner; never print this stream to logs.
func emit(_ value: [String: Any]) throws {
    var data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    data.append(10)
    try FileHandle.standardOutput.write(contentsOf: data)
}

func recoveryKey(_ account: MatrixAccount, user: String) async throws -> String? {
    let item: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "multiplexer-cli-test-recovery", kSecAttrAccount as String: user]
    var query = item
    query[kSecReturnData as String] = true
    var value: CFTypeRef?
    let result = SecItemCopyMatching(query as CFDictionary, &value)
    if result == errSecSuccess, let data = value as? Data, let key = String(data: data, encoding: .utf8) {
        try await account.recover(recoveryKey: key)
        return key
    }
    guard result == errSecItemNotFound else { throw NSError(domain: "test-keychain", code: Int(result)) }
    guard await account.recoveryStatus() == .disabled else { return nil }
    let key = try await account.enableRecovery()
    var add = item
    add[kSecValueData as String] = Data(key.utf8)
    add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else {
        throw NSError(domain: "test-keychain-save", code: 1)
    }
    // keep this test account's backup and private key for reproducible later runs.
    return key
}

let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mx-cli-probe-" + UUID().uuidString)
var account: MatrixAccount?
do {
    guard let line = readLine(), let data = line.data(using: .utf8),
          let input = try JSONSerialization.jsonObject(with: data) as? [String: String],
          let user = input["user"], ["@test1:ramimaalouf.com", "@test2:ramimaalouf.com"].contains(user),
          let password = input["password"], !password.isEmpty else {
        throw NSError(domain: "test-account-only", code: 1)
    }
    let signed = try await MatrixAccount.signIn(homeserver: "ramimaalouf.com", user: user,
        password: password, deviceName: "Mux CLI coverage probe", storeDirectory: directory,
        searchIndexKey: SearchIndex.newKey())
    account = signed
    _ = try await signed.rooms(timeout: 120)
    try emit(["status": "ready", "deviceId": try signed.savedSession().deviceId])
    while let line = readLine() {
        do {
            guard let data = line.data(using: .utf8),
                  let input = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let command = input["command"] as? String else { throw NSError(domain: "protocol", code: 1) }
            switch command {
            case "rooms":
                let rooms = try await signed.rooms(timeout: 120)
                try emit(["rooms": rooms.map { ["id": $0.id, "name": $0.name] }])
            case "create":
                let room = try await signed.createRoom(name: input["name"] as! String,
                    encrypted: input["encrypted"] as? Bool ?? false)
                try emit(["roomId": room])
            case "send":
                let id = try await signed.sendTextConfirmed(roomId: input["roomId"] as! String, text: input["text"] as! String)
                try emit(["eventId": id])
            case "read":
                let values = try await signed.messages(roomId: input["roomId"] as! String, limit: 100, timeout: 120)
                try emit(["messages": values.map { ["eventId": $0.eventId, "text": $0.body, "waitingForKey": $0.waitingForKey] as [String: Any] }])
            case "recovery":
                if let key = try await recoveryKey(signed, user: user) { try emit(["key": key]) }
                else { try emit(["blocked": "existing backup has no test-fixture key; no reset performed"]) }
            case "backup":
                try await signed.waitForBackup()
                try emit(["status": "backed-up"])
            case "merge":
                let rooms = input["rooms"] as! [String]
                let id = try await signed.merge(rooms: rooms, name: input["name"] as! String, defaultRoom: rooms[0])
                try emit(["chatId": id])
            case "quit":
                try await signed.signOut()
                account = nil
                try emit(["status": "signed-out"])
                try? FileManager.default.removeItem(at: directory)
                exit(0)
            default: throw NSError(domain: "protocol", code: 2)
            }
        } catch {
            // arbitrary sdk errors can contain request bodies or encryption details.
            try emit(["error": "fixture operation failed"])
        }
    }
    try await signed.signOut()
    account = nil
    try? FileManager.default.removeItem(at: directory)
    exit(0)
} catch {
    if let account { try? await account.signOut() }
    try? FileManager.default.removeItem(at: directory)
    FileHandle.standardError.write(Data("test fixture failed\n".utf8))
    exit(1)
}
