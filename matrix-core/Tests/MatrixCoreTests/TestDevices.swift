@testable import MatrixCore
import XCTest

extension XCTestCase {
    /// Signs in as a new device of a test user, with a store of its own, and signs it out at the
    /// test's end, even when the test failed. The server limits sign-ins, and other tests sign in as
    /// the same users: a refusal waits and tries again.
    ///
    /// The first sync starts here, with a 120 s limit. A new device's first sync is mostly work on
    /// the device (its crypto store, its database), which a busy Mac (several simulators and builds)
    /// stretched past the 30 s that `rooms()` waits by default: measured 2026-11-03, a new device of
    /// one test user took 12.5 s to sync and another more than 30 s, while the server answered the
    /// same sync in 0.2 s.
    func signInTestDevice(_ homeserver: String, _ user: String, _ password: String,
                          searchIndexKey: String? = nil) async throws -> MatrixAccount {
        for attempt in 1... {
            do {
                let account = try await MatrixAccount.signIn(
                    homeserver: homeserver, user: user, password: password, deviceName: "Multiplexer test",
                    storeDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("matrix-core-\(UUID().uuidString)"),
                    searchIndexKey: searchIndexKey)
                let saved = try? account.savedSession()
                addTeardownBlock { await Self.signOutTestDevice(account, saved: saved) }
                _ = try await account.rooms(timeout: 120)
                return account
            } catch SignInError.rateLimited where attempt < 4 {
                try await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
        fatalError("unreachable")
    }

    /// Signs a test device out. If its own client cannot (its sync never started, or the test
    /// signed it out already), its saved session is signed out through a scratch store, so no
    /// device is left on the account.
    static func signOutTestDevice(_ account: MatrixAccount, saved: SavedSession?) async {
        do {
            try await account.signOut()
        } catch {
            guard let saved else {
                print("a test device did not sign out, and has no saved session: \(error)")
                return
            }
            let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("matrix-core-signout-\(UUID().uuidString)")
            if !(await MatrixAccount.signOutOnServer(saved, scratchDirectory: scratch)) {
                print("a test device \(saved.deviceId) is left on \(saved.userId): \(error)")
            }
        }
    }
}
