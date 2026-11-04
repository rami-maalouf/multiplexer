import Foundation
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// Why a recovery key did not open the account's backup.
public enum RecoveryKeyError: Error, Equatable {
    /// The key is not this account's, or it was mistyped.
    case wrongKey
    /// Another failure (the server could not be reached): its text, for the log.
    case failed(String)
}

/// The account's recovery: a backup of its message keys on the server, opened with a recovery
/// key (made by this app or another, such as Element). A device that opens it reads the
/// encrypted messages it had no key for, older ones too.
extension MatrixAccount {
    /// Opens the account's backup with its recovery key. The chats are told, and a message that
    /// was "waiting" fetches its key from the backup as it shows again.
    public func recover(recoveryKey: String) async throws {
        let key = recoveryKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let encryption = client.encryption()
        await encryption.waitForE2eeInitializationTasks()
        do {
            try await encryption.recover(recoveryKey: key)
        } catch let error as RecoveryError {
            switch error {
            case .SecretStorage, .Import: throw RecoveryKeyError.wrongKey
            default: throw RecoveryKeyError.failed("\(error)")
            }
        }
        // the sdk says so a moment later: Settings then shows recovery on, not the old state.
        let start = Date()
        while encryption.recoveryState() != .enabled, encryption.backupState() != .enabled, Date().timeIntervalSince(start) < 10 {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        // the open chats try their waiting messages again: a failure now fetches the key.
        for roomId in openRoomIds() {
            guard let live = try? await liveTimeline(roomId, limit: 20, timeout: 30) else { continue }
            let sessions = live.items.read { items, _ in
                items.compactMap { item -> String? in
                    guard case .msgLike(let like)? = item.asEvent()?.content, case .unableToDecrypt(let message) = like.kind,
                          case .megolmV1AesSha2(let sessionId, _) = message else { return nil }
                    return sessionId
                }
            }
            if !sessions.isEmpty { live.timeline.retryDecryption(sessionIds: Array(Set(sessions))) }
            notify(.room(roomId))
        }
        notify(.rooms)
    }

    /// Sets up recovery for an account that has none, and returns its new recovery key once
    /// this device's keys are in the backup.
    public func enableRecovery() async throws -> String {
        let encryption = client.encryption()
        await encryption.waitForE2eeInitializationTasks()
        return try await encryption.enableRecovery(waitForBackupsToUpload: true, passphrase: nil, progressListener: RecoveryProgress())
    }

    /// Turns the account's recovery off: its backup and the key's storage go from the server.
    public func disableRecovery() async throws {
        let encryption = client.encryption()
        await encryption.waitForE2eeInitializationTasks()
        try await encryption.disableRecovery()
    }

    /// Waits until this device's message keys are in the backup.
    public func waitForBackup() async throws {
        try await client.encryption().waitForBackupUploadSteadyState(progressListener: nil)
    }
}

private final class RecoveryProgress: EnableRecoveryProgressListener, @unchecked Sendable {
    func onUpdate(status: EnableRecoveryProgress) {}
}
