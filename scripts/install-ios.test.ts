import { expect, test } from 'bun:test';
import { builtApp, grantsCommunicationNotifications, installIOS } from './install-ios.ts';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

test('the installer selects only the completed build app, including paths with spaces', () => {
  const dir = mkdtempSync(join(tmpdir(), 'mux-build-'));
  const app = join(dir, 'Mux test.app');
  Bun.spawnSync(['mkdir', app]);
  try {
    expect(builtApp(`warning: old.app\nhost/apple: ${app} on test device (cargo 1 s)\n`)).toBe(app);
    expect(() => builtApp('build failed')).toThrow('did not report');
    expect(() => builtApp('host/apple: /missing/Mux.app on device\n')).toThrow('did not report');
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('bad arguments fail before building or installing', async () => {
  for (const args of [[], ['--sim'], ['--run', 'device'], ['--device', '--run']]) {
    await expect(installIOS(args)).rejects.toThrow('usage:');
  }
});

test.skipIf(process.platform !== 'darwin')('profile preflight accepts certificate data and dates while requiring the communication grant', () => {
  const profile = (entitlements: string) => new TextEncoder().encode(`<?xml version="1.0"?>
    <plist version="1.0"><dict>
    <key>DeveloperCertificates</key><array><data>AQID</data></array>
    <key>ExpirationDate</key><date>2027-11-12T14:02:39Z</date>
    <key>Entitlements</key><dict>${entitlements}</dict></dict></plist>`);
  const key = '<key>com.apple.developer.usernotifications.communication</key>';
  expect(grantsCommunicationNotifications(profile(`${key}<true/>`))).toBe(true);
  expect(grantsCommunicationNotifications(profile(`${key}<false/>`))).toBe(false);
  expect(grantsCommunicationNotifications(profile(''))).toBe(false);
  expect(grantsCommunicationNotifications(new TextEncoder().encode('not a profile'))).toBe(false);
});
