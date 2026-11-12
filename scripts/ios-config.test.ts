import { expect, test } from 'bun:test';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { loadIOSConfig, loadIOSDefaults, validateIOSConfig, validateDevelopmentProfile } from './ios-config.ts';
import { configureIOS } from './configure-ios.ts';

const custom = { teamId: 'ABCDE12345', bundleId: 'org.example.chat', pushGateway: 'https://push.example.org/_matrix/push/v1/notify' };
function fixture() {
  const root = mkdtempSync(join(tmpdir(), 'mux-config-'));
  mkdirSync(join(root, 'apps/multiplexer'), { recursive: true });
  writeFileSync(join(root, 'ios.config.json'), JSON.stringify(custom));
  writeFileSync(join(root, 'apps/multiplexer/app.json'), JSON.stringify({ id: 'old.app', app: { id: 'old.app', name: 'Mux' } }));
  return root;
}
test('custom configuration derives every shared identity and setup synchronizes both manifest ids', () => {
  const root = fixture();
  const previous = process.env.MUX_IOS_CONFIG;
  process.env.MUX_IOS_CONFIG = join(root, 'ios.config.local.json');
  try {
    configureIOS(['--team-id', custom.teamId, '--bundle-id', custom.bundleId, '--push-gateway', custom.pushGateway], root);
    expect(loadIOSConfig(root)).toMatchObject({ ...custom, extensionId: 'org.example.chat.notifications', appGroup: 'group.org.example.chat', keychainGroup: 'ABCDE12345.org.example.chat', sessionService: 'org.example.chat.session', pusherAppId: 'org.example.chat.ios', developmentPusherAppId: 'org.example.chat.ios.dev' });
    expect(JSON.parse(readFileSync(join(root, 'apps/multiplexer/app.json'), 'utf8'))).toEqual({ id: custom.bundleId, app: { id: custom.bundleId, name: 'Mux' } });
  } finally {
    if (previous === undefined) delete process.env.MUX_IOS_CONFIG;
    else process.env.MUX_IOS_CONFIG = previous;
    rmSync(root, { recursive: true, force: true });
  }
});
test('invalid setup validates before writing and rejects credentials, non-https and invalid identities', () => {
  const root = fixture();
  try {
    const before = readFileSync(join(root, 'apps/multiplexer/app.json'), 'utf8');
    expect(() => configureIOS(['--team-id', custom.teamId, '--bundle-id', custom.bundleId, '--push-gateway', 'http://push.example.org/_matrix/push/v1/notify'], root)).toThrow();
    expect(readFileSync(join(root, 'apps/multiplexer/app.json'), 'utf8')).toBe(before);
    for (const input of [{ ...custom, teamId: 'bad' }, { ...custom, bundleId: 'org.*' }, { ...custom, pushGateway: 'https://user:pass@example.org/_matrix/push/v1/notify' }, { ...custom, pushGateway: custom.pushGateway + '?token=secret' }, { ...custom, extra: true }]) expect(() => validateIOSConfig(input)).toThrow();
  } finally { rmSync(root, { recursive: true, force: true }); }
});
test('development profile rejects identity, team, groups, apns, device and communication mismatches', () => {
  const config = validateIOSConfig(custom);
  const profile = { ExpirationDate: '2099-01-01', ProvisionedDevices: ['phone'], Entitlements: { 'application-identifier': 'ABCDE12345.org.example.chat', 'com.apple.developer.team-identifier': custom.teamId, 'keychain-access-groups': ['ABCDE12345.*'], 'com.apple.security.application-groups': ['group.org.example.chat'], 'aps-environment': 'development', 'get-task-allow': true, 'com.apple.developer.usernotifications.communication': true } };
  expect(() => validateDevelopmentProfile(profile, config, 'app', 'phone')).not.toThrow();
  for (const [key, value] of Object.entries({ 'application-identifier': 'ABCDE12345.other.app', 'com.apple.developer.team-identifier': 'OTHER12345', 'keychain-access-groups': ['OTHER12345.*'], 'com.apple.security.application-groups': [], 'aps-environment': 'production', 'get-task-allow': false, 'com.apple.developer.usernotifications.communication': false })) {
    expect(() => validateDevelopmentProfile({ ...profile, Entitlements: { ...profile.Entitlements, [key]: value } }, config, 'app', 'phone')).toThrow();
  }
  expect(() => validateDevelopmentProfile({ ...profile, ProvisionedDevices: ['other'] }, config, 'app', 'phone')).toThrow();
  expect(() => validateDevelopmentProfile({ ...profile, ExpirationDate: '2000-01-01' }, config, 'app', 'phone')).toThrow();
  expect(() => validateDevelopmentProfile(profile, config, 'extension', 'phone')).toThrow();
  const extension = { ...profile, Entitlements: { ...profile.Entitlements, 'application-identifier': 'ABCDE12345.org.example.chat.notifications', 'com.apple.developer.usernotifications.communication': false } };
  expect(() => validateDevelopmentProfile(extension, config, 'extension', 'phone')).not.toThrow();
});

test('maintainer defaults preserve existing session, groups and gateway', () => {
  const config = loadIOSDefaults();
  expect(config).toMatchObject({ bundleId: 'com.ramimaalouf.multiplexer', teamId: '3V2UU7RRK9', appGroup: 'group.com.ramimaalouf.multiplexer', sessionService: 'com.ramimaalouf.multiplexer.session', keychainGroup: '3V2UU7RRK9.com.ramimaalouf.multiplexer', pushGateway: 'https://sygnal.ramimaalouf.com/_matrix/push/v1/notify' });
});

test('the actual Swift runtime reads a custom packaged bundle and preserves bare agent sessions', () => {
  const root = fixture();
  try {
    const source = readFileSync(join(import.meta.dir, '../apps/multiplexer/modules/apple/PushRegistration.swift'), 'utf8');
    const helper = source.slice(source.indexOf('enum IOSPushConfiguration'), source.indexOf('/// Push (Phase 3):'));
    const bundle = join(root, 'Fixture.app/Contents');
    mkdirSync(join(bundle, 'MacOS'), { recursive: true });
    writeFileSync(join(bundle, 'Info.plist'), `<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>org.example.chat</string><key>CFBundleExecutable</key><string>fixture</string><key>MultiplexerAppGroup</key><string>group.org.example.chat</string><key>MultiplexerSessionService</key><string>org.example.chat.session</string><key>MultiplexerPushGateway</key><string>${custom.pushGateway}</string></dict></plist>`);
    const fixturePath = join(root, 'main.swift');
    writeFileSync(fixturePath, `import Foundation\n${helper}\nprecondition(IOSPushConfiguration.bundleId == "org.example.chat")\nprecondition(IOSPushConfiguration.sessionService(agent: false) == "org.example.chat.session")\nprecondition(IOSPushConfiguration.sessionService(agent: true) == "org.example.chat.session.agent")\nprecondition(IOSPushConfiguration.appGroup == "group.org.example.chat")\nprecondition(IOSPushConfiguration.pushGateway == "${custom.pushGateway}")\nprecondition(IOSPushConfiguration.pusherAppId(development: false) == "org.example.chat.ios")\nprecondition(IOSPushConfiguration.pusherAppId(development: true) == "org.example.chat.ios.dev")\n`);
    const binary = join(bundle, 'MacOS/fixture');
    const compile = Bun.spawnSync(['swiftc', fixturePath, '-o', binary]);
    expect(compile.exitCode, compile.stderr.toString()).toBe(0);
    const result = Bun.spawnSync([binary]);
    expect(result.exitCode, result.stderr.toString()).toBe(0);
    writeFileSync(fixturePath, `import Foundation\n${helper}\nprecondition(IOSPushConfiguration.sessionService(agent: true) == "com.ramimaalouf.multiplexer.session.agent")\n`);
    const bare = join(root, 'bare');
    expect(Bun.spawnSync(['swiftc', fixturePath, '-o', bare]).exitCode).toBe(0);
    expect(Bun.spawnSync([bare]).exitCode).toBe(0);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test('profile field extraction retains expiry and devices without JSON-converting certificates or dates', async () => {
  const { decodeDevelopmentProfile } = await import('./ios-config.ts');
  const xml = new TextEncoder().encode(`<?xml version="1.0"?><plist version="1.0"><dict>
    <key>DeveloperCertificates</key><array><data>AQID</data></array>
    <key>ExpirationDate</key><date>2099-11-12T14:02:39Z</date>
    <key>ProvisionedDevices</key><array><string>phone</string></array>
    <key>Entitlements</key><dict><key>get-task-allow</key><true/></dict>
  </dict></plist>`);
  const decoded = decodeDevelopmentProfile(xml);
  expect(decoded.ProvisionedDevices).toEqual(['phone']);
  expect(Date.parse(decoded.ExpirationDate!)).toBe(Date.parse('2099-11-12T14:02:39Z'));
  expect(decoded.Entitlements).toEqual({ 'get-task-allow': true });
});

test('installer rejects a mismatched development profile before invoking the build', () => {
  const root = fixture();
  try {
    const scripts = join(root, 'scripts');
    mkdirSync(scripts);
    for (const name of ['install-ios.ts', 'ios-config.ts']) writeFileSync(join(scripts, name), readFileSync(join(import.meta.dir, name)));
    writeFileSync(join(root, 'apps/multiplexer/app.json'), JSON.stringify({ id: custom.bundleId, app: { id: custom.bundleId } }));
    const bin = join(root, 'bin');
    mkdirSync(bin);
    const profile = join(root, 'wrong.mobileprovision');
    writeFileSync(profile, `<?xml version="1.0"?><plist version="1.0"><dict><key>ExpirationDate</key><date>2099-11-12T14:02:39Z</date><key>ProvisionedDevices</key><array><string>phone</string></array><key>Entitlements</key><dict><key>application-identifier</key><string>OTHER12345.com.ramimaalouf.multiplexer</string><key>com.apple.developer.team-identifier</key><string>OTHER12345</string><key>com.apple.developer.usernotifications.communication</key><true/></dict></dict></plist>`);
    writeFileSync(join(bin, 'security'), '#!/bin/sh\n/bin/cat "$4"\n', { mode: 0o755 });
    writeFileSync(join(bin, 'bun'), '#!/bin/sh\necho unexpected-build >&2\nexit 95\n', { mode: 0o755 });
    const result = Bun.spawnSync([process.execPath, join(scripts, 'install-ios.ts'), '--device', 'phone'], { env: { ...process.env, MUX_IOS_CONFIG: join(root, 'ios.config.json'), APP_PROFILE: profile, EXTENSION_PROFILE: profile, PATH: `${bin}:${process.env.PATH}` } });
    expect(result.exitCode).toBe(1);
    expect(result.stderr.toString()).toContain('does not match configured identity/team');
    expect(result.stderr.toString()).not.toContain('unexpected-build');
  } finally { rmSync(root, { recursive: true, force: true }); }
});
