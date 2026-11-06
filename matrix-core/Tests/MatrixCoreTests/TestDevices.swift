@testable import MatrixCore
import XCTest

/// One signed-in device per test user (and search index key) for a whole test run. Each new device's
/// first sync is mostly work on the device and took up to 27 s on a busy Mac, so signing in once per
/// test made the suite slow and filled the account with devices. The first test that asks signs it
/// in and waits for its first sync; every later test gets the same `MatrixAccount`; the run signs
/// them out when the test bundle finishes. A shared device is held: a test's `signOut()` closes only
/// what that test opened.
final class SharedTestDevices: NSObject, XCTestObservation, @unchecked Sendable {
    static let shared = SharedTestDevices()
    private let lock = NSLock()
    private var devices: [String: Task<MatrixAccount, Error>] = [:]
    private var claimed: [ObjectIdentifier: Set<String>] = [:]
    private var observing = false
    /// sign-ins this run made, shared and fresh: the run prints them at its end.
    private(set) var signIns = (shared: 0, fresh: 0)

    func countFresh() { lock.withLock { signIns.fresh += 1 } }

    /// Whether `test` may use the shared device of `key`: only once per test. A second device of the
    /// same user in one test is a new device, which that test is about.
    func claim(_ test: XCTestCase, _ key: String) -> Bool {
        lock.withLock { claimed[ObjectIdentifier(test), default: []].insert(key).inserted }
    }

    func release(_ test: XCTestCase) { _ = lock.withLock { claimed.removeValue(forKey: ObjectIdentifier(test)) } }

    func account(_ key: String, _ homeserver: String, _ user: String, _ password: String,
                 searchIndexKey: String?) async throws -> MatrixAccount {
        let task: Task<MatrixAccount, Error> = lock.withLock {
            if !observing {
                observing = true
                // XCTest's observers are added on the main thread; an async test may run elsewhere.
                if Thread.isMainThread { XCTestObservationCenter.shared.addTestObserver(self) }
                else { DispatchQueue.main.async { XCTestObservationCenter.shared.addTestObserver(self) } }
            }
            if let task = devices[key] { return task }
            signIns.shared += 1
            let task = Task {
                let account = try await XCTestCase.signInDevice(homeserver, user, password, searchIndexKey: searchIndexKey,
                                                                folder: "matrix-core-shared-\(UUID().uuidString)")
                account.holdForTests(true)
                return account
            }
            devices[key] = task
            return task
        }
        do { return try await task.value } catch {
            lock.withLock { devices[key] = nil }
            throw error
        }
    }

    /// The run's end: each shared device signs out, so none is left on the account.
    func testBundleDidFinish(_ testBundle: Bundle) {
        let (tasks, counts) = lock.withLock { (Array(devices.values), signIns) }
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            for task in tasks {
                guard let account = try? await task.value else { continue }
                account.holdForTests(false)
                await XCTestCase.signOutTestDevice(account, saved: try? account.savedSession())
            }
            done.signal()
        }
        _ = done.wait(timeout: .now() + 60)
        print("test devices: \(counts.shared) shared and \(counts.fresh) fresh sign-ins this run")
    }
}

extension XCTestCase {
    /// The run's shared device of `user` (see `SharedTestDevices`): signed in once, its first sync
    /// done. A second call for the same user in one test returns a new device instead, as a test of two
    /// devices of one account needs. What the test opened on the shared device is closed at its end.
    func testAccount(_ homeserver: String, _ user: String, _ password: String,
                     searchIndexKey: String? = nil) async throws -> MatrixAccount {
        let devices = SharedTestDevices.shared, key = "\(homeserver) \(user) \(searchIndexKey ?? "")"
        guard devices.claim(self, key) else {
            return try await signInTestDevice(homeserver, user, password, searchIndexKey: searchIndexKey)
        }
        let account = try await devices.account(key, homeserver, user, password, searchIndexKey: searchIndexKey)
        addTeardownBlock {
            account.closeOpenedForTests()
            devices.release(self)
        }
        return account
    }

    /// Signs in a device with a store of its own and waits for its first sync (120 s at most). The
    /// server limits sign-ins, and other runs sign in as the same users: a refusal waits and tries again.
    static func signInDevice(_ homeserver: String, _ user: String, _ password: String, searchIndexKey: String?,
                             folder: String) async throws -> MatrixAccount {
        for attempt in 1... {
            do {
                let account = try await MatrixAccount.signIn(
                    homeserver: homeserver, user: user, password: password, deviceName: "Multiplexer test",
                    storeDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(folder),
                    searchIndexKey: searchIndexKey)
                _ = try await account.rooms(timeout: 120)
                return account
            } catch SignInError.rateLimited where attempt < 4 {
                try await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
        fatalError("unreachable")
    }

    /// FRESH DEVICE: signs in as a new device of a test user, with a store of its own, and signs it
    /// out at the test's end, even when the test failed. Only for a test whose point is a new device
    /// (its first sync, recovery, a second device, sign-out); every other test takes `testAccount`. The server limits sign-ins, and other tests sign in as
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
                SharedTestDevices.shared.countFresh()
                print("fresh test device: \(name) as \(user)")
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
