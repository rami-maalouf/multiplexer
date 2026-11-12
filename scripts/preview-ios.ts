import { loadIOSConfig, loadIOSDefaults, checkIOSManifest } from './ios-config.ts';
import { existsSync, mkdtempSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

function run(args: string[]): string {
  const result = Bun.spawnSync(args, { stdout: 'pipe', stderr: 'pipe' });
  if (result.exitCode !== 0) throw new Error(`${args[0]} failed: ${result.stderr.toString().trim()}`);
  return result.stdout.toString();
}

function plist(path: string): any {
  return JSON.parse(run(['plutil', '-convert', 'json', '-o', '-', path]));
}

function entitlements(path: string): any {
  const xml = run(['codesign', '-d', '--entitlements', ':-', path]);
  const converted = Bun.spawnSync(['plutil', '-convert', 'json', '-o', '-', '-'], { stdin: Buffer.from(xml) });
  if (converted.exitCode !== 0) throw new Error('could not read preview notification entitlements');
  return JSON.parse(converted.stdout.toString());
}

export function packagePreview(archive: string): string {
  const applications = join(resolve(archive), 'Products/Applications');
  const apps = readdirSync(applications).filter(name => name.endsWith('.app'));
  if (apps.length !== 1) throw new Error('expected exactly one app in the preview archive');
  const app = join(applications, apps[0]);
  const extension = join(app, 'PlugIns/MultiplexerNotifications.appex');
  if (!existsSync(extension)) throw new Error('preview is missing its notification extension; build with scripts/testflight.sh --archive-only');
  const info = plist(join(app, 'Info.plist'));
  const ext = plist(join(extension, 'Info.plist'));
  const config = loadIOSConfig();
  const bundle = config.bundleId;
  if (info.CFBundleIdentifier !== bundle || ext.CFBundleIdentifier !== config.extensionId
      || info.CFBundleVersion !== ext.CFBundleVersion
      || ext.MultiplexerAppGroup !== config.appGroup
      || ext.MultiplexerKeychainGroup !== config.keychainGroup
      || ext.MultiplexerSessionService !== config.sessionService
      || !info.NSUserActivityTypes?.includes('INSendMessageIntent')
      || !ext.NSUserActivityTypes?.includes('INSendMessageIntent')) {
    throw new Error('preview app and notification extension have inconsistent identities or shared-session configuration');
  }
  const metadata = {
    MultiplexerPushGateway: config.pushGateway,
    MultiplexerAppGroup: config.appGroup,
    MultiplexerKeychainGroup: config.keychainGroup,
    MultiplexerSessionService: config.sessionService,
  };
  // existing maintainer archives predate main-bundle metadata and use the same runtime defaults.
  const defaults = loadIOSDefaults();
  const legacy = config.bundleId === defaults.bundleId && config.teamId === defaults.teamId && config.pushGateway === defaults.pushGateway;
  for (const [key, value] of Object.entries(metadata)) {
    if (info[key] !== value && !(legacy && info[key] === undefined)) throw new Error('preview runtime configuration differs from ios configuration');
  }
  for (const [path, id] of [[app, bundle], [extension, config.extensionId]]) {
    const ent = entitlements(path);
    if (ent['application-identifier'] !== `${config.teamId}.${id}`
        || ent['get-task-allow'] !== false
        || !ent['com.apple.security.application-groups']?.includes(config.appGroup)
        || !ent['keychain-access-groups']?.includes(config.keychainGroup)) {
      throw new Error('preview is missing distribution identity or shared-session entitlements');
    }
  }
  const ent = entitlements(app);
  if (ent['aps-environment'] !== 'production'
      || ent['com.apple.developer.usernotifications.communication'] !== true) {
    throw new Error('preview is missing production push or sender-photo entitlements');
  }
  run(['codesign', '--verify', '--deep', '--strict', app]);
  const work = mkdtempSync(join(tmpdir(), 'mux-preview-'));
  const payload = join(work, 'Payload');
  const ipa = join(work, 'Mux.ipa');
  try {
    run(['ditto', applications, payload]);
    run(['ditto', '-c', '-k', '--keepParent', payload, ipa]);
  } finally { rmSync(payload, { recursive: true, force: true }); }
  return ipa;
}

export function previewIOS(args: string[]): string {
  if (args.length !== 1 || !/^\d+$/.test(args[0])) throw new Error('usage: bun scripts/preview-ios.ts <build number>');
  checkIOSManifest(loadIOSConfig());
  const result = Bun.spawnSync(['bash', resolve(import.meta.dir, 'testflight.sh'), args[0], '--archive-only'],
    { stdout: 'pipe', stderr: 'inherit' });
  process.stdout.write(result.stdout);
  if (result.exitCode !== 0) throw new Error('preview archive build failed; nothing was uploaded');
  const archive = result.stdout.toString().match(/^archive: (.+)$/m)?.[1];
  if (!archive) throw new Error('build did not report a completed archive');
  return packagePreview(archive);
}

if (import.meta.main) {
  try {
    const ipa = previewIOS(process.argv.slice(2));
    console.log(`notification-capable preview: ${ipa}`);
    console.log('use your configured Apple team for distribution signing; nothing was uploaded');
  } catch (error) { console.error(error instanceof Error ? error.message : String(error)); process.exitCode = 1; }
}
