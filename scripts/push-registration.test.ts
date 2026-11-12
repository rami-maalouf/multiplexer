import { expect, test } from 'bun:test';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

// execute the app's actual registration methods with controlled token, server and keychain io.
// no sdk or network: these checks exercise failure ordering and suspension across session changes.
test('native push registration preserves the old route and current session through failures', () => {
  const root = resolve(import.meta.dir, '..');
  const path = 'apps/multiplexer/modules/apple/PushRegistration.swift';
  const baseline = process.env.MUX_PUSH_BASELINE;
  const original = baseline
    ? Bun.spawnSync(['git', 'show', `${baseline}:${path}`], { cwd: root }).stdout.toString()
    : readFileSync(join(root, path), 'utf8');
  const source = original.split('\n#if os(iOS)\n/// The APNs token:')[0]
    .replace('#if os(iOS)\nimport UIKit\n#endif', '')
    .replaceAll('#if os(iOS)', '#if PUSH_REGISTRATION_TEST');
  const directory = mkdtempSync(join(tmpdir(), 'mux-push-regression-'));
  try {
    writeFileSync(join(directory, 'PushRegistration.swift'), source);
    writeFileSync(join(directory, 'Fixture.swift'), `
import Foundation
struct Session { var userId = "@test1"; var deviceId = "device"; var accessToken = "old" }
struct StoredSession { var session = Session(); var store = "store"; var pushkey: String? = "old-key"; var pusherAppId: String? = "app" }
struct Pusher {
    var appId: String; var pushkey: String; var url: String; var appDisplayName: String; var deviceDisplayName: String
    static func pushkey(apnsToken: Data) -> String { "new-key" }
}
final class Keychain { var value: StoredSession? = StoredSession(); func read() throws -> StoredSession? { value }; func write(_ value: StoredSession) throws { self.value = value } }
enum Problem: Error { case offline }
@MainActor enum PushToken {
    static var appId = "app"; static var isDevelopment = false
    static var requestBody: () async throws -> Data = { Data([1]) }
    static func request() async throws -> Data { try await requestBody() }
}
func moduleLog(_ line: String) {}
@MainActor final class MatrixAccount {
    var userId: String { get throws { "@test1" } }
    func savedSession() throws -> Session { Session() }
    var operations: [String] = []; var failsSet = false; var failsDelete = false
    var duringSet: () -> Void = {}
    func setPusher(_ pusher: Pusher) async throws { operations.append("set"); duringSet(); if failsSet { throw Problem.offline } }
    func deletePusher(appId: String, pushkey: String) async throws { operations.append("delete"); if failsDelete { throw Problem.offline } }
}
@MainActor final class Matrix {
    let keychain = Keychain(); let account = MatrixAccount(); let context = Context()
    struct Context { var agent = false }
    func signedIn() async throws -> MatrixAccount { account }
    func sendsReadReceipts(_ account: MatrixAccount) throws -> Bool { true }
}
@main struct Regression {
    @MainActor static func main() async throws {
        let failed = Matrix(); failed.account.failsSet = true
        do { _ = try await failed.registerPush() } catch {}
        precondition(failed.account.operations == ["set"], "a failed replacement deleted the working route")
        precondition(failed.keychain.value?.pushkey == "old-key")

        let refreshed = Matrix()
        refreshed.account.duringSet = { refreshed.keychain.value?.session.accessToken = "refreshed" }
        _ = try await refreshed.registerPush()
        precondition(refreshed.account.operations == ["set", "delete"], "replacement must precede removal")
        precondition(refreshed.keychain.value?.session.accessToken == "refreshed", "registration overwrote a refreshed session")
        precondition(refreshed.keychain.value?.pushkey == "new-key")

        let changedWhileWaiting = Matrix()
        PushToken.requestBody = { changedWhileWaiting.keychain.value?.session.deviceId = "new-device"; return Data([1]) }
        _ = try await changedWhileWaiting.registerPush()
        precondition(changedWhileWaiting.account.operations.isEmpty, "token callback registered a superseded device")
        precondition(changedWhileWaiting.keychain.value?.pushkey == "old-key")
        PushToken.requestBody = { Data([1]) }

        let signedOut = Matrix(); signedOut.account.duringSet = { signedOut.keychain.value = nil }
        _ = try await signedOut.registerPush()
        precondition(signedOut.keychain.value == nil, "an in-flight registration resurrected sign-in")

        let disabling = Matrix(); disabling.account.failsDelete = true
        var threw = false
        do { try await disabling.unregisterPush() } catch { threw = true }
        precondition(threw, "failed disabling must remain retryable")
        precondition(disabling.keychain.value?.pushkey == "old-key", "failed disabling forgot its live route")
        disabling.account.failsDelete = false
        try await disabling.unregisterPush()
        precondition(disabling.keychain.value?.pushkey == nil)
        print("native push failure and session regressions passed")
    }
}
`);
    const binary = join(directory, 'regression');
    const compile = Bun.spawnSync(['xcrun', 'swiftc', '-parse-as-library', '-D', 'PUSH_REGISTRATION_TEST',
      join(directory, 'PushRegistration.swift'), join(directory, 'Fixture.swift'), '-o', binary]);
    expect(compile.stderr.toString()).not.toContain('error:');
    expect(compile.exitCode).toBe(0);
    const run = Bun.spawnSync([binary]);
    if (run.exitCode !== 0) throw new Error(run.stderr.toString().split("\n")[0]);
  } finally { rmSync(directory, { recursive: true, force: true }); }
}, 60_000);
