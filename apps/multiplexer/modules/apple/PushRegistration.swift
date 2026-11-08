import Foundation
#if os(iOS)
import UIKit
#endif

/// Push (Phase 3): the phone's APNs token, given to the server as a pusher (MatrixCore's
/// Push.swift), so a new message reaches the notification extension
/// (`extensions/notifications/`). Exact has no push registration yet (LLP 1133.004 §9), so the
/// token's callbacks are added to its app delegate at run time.
extension Matrix {
    /// Where our server sends each push: the push gateway (Sygnal), at the one path Synapse allows.
    static let pushGateway = "https://sygnal.ramimaalouf.com/_matrix/push/v1/notify"

    /// Asks iOS for the push token, then sets the account's pusher; a new token replaces the
    /// pusher of the old one. False when there is nothing to register: a drive on an account
    /// that is not a test user (AGENTS.md, the safety rule), or no token (no `aps-environment`
    /// in the app's signature, as before P3.0's profiles).
    @MainActor func registerPush() async throws -> Bool {
        let account = try await signedIn()
        guard try sendsReadReceipts(account) else { return false }
        #if os(iOS)
        let token: Data
        do {
            token = try await PushToken.request()
        } catch {
            moduleLog("matrix: no push token: \(error.localizedDescription)")
            return false
        }
        if PushToken.isDevelopment { moduleLog("matrix: push token \(token.map { String(format: "%02x", $0) }.joined())") }
        guard var stored = try keychain.read() else { return false }
        let pusher = Pusher(appId: PushToken.appId, pushkey: Pusher.pushkey(apnsToken: token), url: Self.pushGateway,
                            appDisplayName: "Mux", deviceDisplayName: context.agent ? "Mux test" : "Mux")
        if let oldKey = stored.pushkey, let oldApp = stored.pusherAppId, oldKey != pusher.pushkey || oldApp != pusher.appId {
            try? await account.deletePusher(appId: oldApp, pushkey: oldKey)
        }
        try await account.setPusher(pusher)
        stored.pushkey = pusher.pushkey
        stored.pusherAppId = pusher.appId
        try keychain.write(stored)
        moduleLog("matrix: pusher set for \(pusher.appId)")
        return true
        #else
        // the mac app shows local notifications from its own sync while it runs: no apns pusher.
        return false
        #endif
    }

    /// Stops the server pushing to this device, before Sign Out forgets the session.
    @MainActor func deletePusher(_ account: MatrixAccount, _ stored: StoredSession?) async {
        guard let pushkey = stored?.pushkey, let appId = stored?.pusherAppId else { return }
        do {
            try await account.deletePusher(appId: appId, pushkey: pushkey)
        } catch {
            // the server also drops a device's pushers when the device signs out.
            moduleLog("matrix: the pusher stays until the server forgets the device: \(error.localizedDescription)")
        }
    }

    /// Permission left `granted` (turned off in the iPhone's Settings): drop this device's
    /// pusher and forget its stored key so a later Allow can register cleanly.
    @MainActor func unregisterPush() async throws {
        guard var stored = try keychain.read() else { return }
        guard stored.pushkey != nil, stored.pusherAppId != nil else { return }
        let account = try await signedIn()
        await deletePusher(account, stored)
        stored.pushkey = nil
        stored.pusherAppId = nil
        try keychain.write(stored)
        moduleLog("matrix: pusher cleared after notifications left granted")
    }
}

#if os(iOS)
/// The APNs token: iOS hands it to the app delegate, which is Exact's, so its two callbacks are
/// added to the delegate's class the first time (`class_addMethod`). A delegate that already has
/// them (a later Exact) keeps its own, and the token does not come here: that is logged.
@MainActor enum PushToken {
    private static var waiting: [UUID: CheckedContinuation<Data, Error>] = [:]
    private static var installed = false

    /// The gateway's name for this app and its APNs environment (Sygnal's config, P3.3).
    static var appId: String { "com.ramimaalouf.multiplexer.ios" + (isDevelopment ? ".dev" : "") }

    /// APNs' sandbox: the Simulator, and a build whose profile says `aps-environment development`.
    /// An App Store or TestFlight build has no embedded profile and pushes in production.
    static var isDevelopment: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else { return false }
        // the profile is a signed message whose plist is in clear text.
        let text = String(decoding: data, as: UTF8.self)
        return text.range(of: "<key>aps-environment</key>\\s*<string>development</string>", options: .regularExpression) != nil
        #endif
    }

    static func request(timeout: TimeInterval = 20) async throws -> Data {
        install()
        let id = UUID()
        return try await withCheckedThrowingContinuation { continuation in
            waiting[id] = continuation
            UIApplication.shared.registerForRemoteNotifications()
            // this request's own deadline: a later request keeps its own.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                waiting.removeValue(forKey: id)?.resume(throwing: URLError(.timedOut))
            }
        }
    }

    /// iOS answers every request at once: each one waiting gets the token or the error.
    private static func deliver(_ result: Result<Data, Error>) {
        let all = waiting.values
        waiting = [:]
        for continuation in all { continuation.resume(with: result) }
    }

    private static func install() {
        guard !installed, let delegate = UIApplication.shared.delegate, let type = object_getClass(delegate) else { return }
        installed = true
        let registered: @convention(block) (AnyObject, UIApplication, Data) -> Void = { _, _, token in
            MainActor.assumeIsolated { deliver(.success(token)) }
        }
        let failed: @convention(block) (AnyObject, UIApplication, NSError) -> Void = { _, _, error in
            MainActor.assumeIsolated { deliver(.failure(error)) }
        }
        let added = [
            class_addMethod(type, #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)),
                            imp_implementationWithBlock(registered), "v@:@@"),
            class_addMethod(type, #selector(UIApplicationDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:)),
                            imp_implementationWithBlock(failed), "v@:@@"),
        ]
        if added.contains(false) { moduleLog("matrix: the app delegate has its own push token callbacks; the token will not come here") }
    }
}
#endif
