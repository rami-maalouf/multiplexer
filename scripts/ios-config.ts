import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

export const repositoryRoot = resolve(import.meta.dir, '..');
export type IOSSettings = { teamId: string; bundleId: string; pushGateway: string };
export type IOSConfig = IOSSettings & { extensionId: string; appGroup: string; keychainGroup: string; sessionService: string; pusherAppId: string; developmentPusherAppId: string };

export function validateIOSConfig(value: unknown): IOSConfig {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('ios configuration must be a JSON object');
  const settings = value as IOSSettings;
  if (Object.keys(value).sort().join(',') !== 'bundleId,pushGateway,teamId') throw new Error('ios configuration requires exactly teamId, bundleId and pushGateway');
  if (typeof settings.teamId !== 'string' || !/^[A-Z0-9]{10}$/.test(settings.teamId)) throw new Error('teamId must be the 10-character Apple team identifier');
  if (typeof settings.bundleId !== 'string' || settings.bundleId.length > 180 || !/^[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$/.test(settings.bundleId)) throw new Error('bundleId must be a unique reverse-domain identifier without wildcards');
  if (typeof settings.pushGateway !== 'string' || /[\s<>"'&]/.test(settings.pushGateway)) throw new Error('pushGateway must be a nonsecret HTTPS Matrix notification URL');
  let url: URL;
  try { url = new URL(settings.pushGateway); } catch { throw new Error('pushGateway must be a valid HTTPS URL'); }
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash || url.pathname !== '/_matrix/push/v1/notify') throw new Error('pushGateway must use HTTPS, the /_matrix/push/v1/notify path, and no credentials, query or fragment');
  const { teamId, bundleId, pushGateway } = settings;
  return { teamId, bundleId, pushGateway, extensionId: `${bundleId}.notifications`, appGroup: `group.${bundleId}`, keychainGroup: `${teamId}.${bundleId}`, sessionService: `${bundleId}.session`, pusherAppId: `${bundleId}.ios`, developmentPusherAppId: `${bundleId}.ios.dev` };
}

export function loadIOSDefaults(root = repositoryRoot): IOSConfig {
  return validateIOSConfig(JSON.parse(readFileSync(resolve(root, 'ios.config.json'), 'utf8')));
}

export function loadIOSConfig(root = repositoryRoot): IOSConfig {
  const local = resolve(root, 'ios.config.local.json');
  const path = process.env.MUX_IOS_CONFIG ? resolve(process.env.MUX_IOS_CONFIG) : existsSync(local) ? local : resolve(root, 'ios.config.json');
  return validateIOSConfig(JSON.parse(readFileSync(path, 'utf8')));
}

export function checkIOSManifest(config: IOSConfig, root = repositoryRoot): void {
  const manifest = JSON.parse(readFileSync(resolve(root, 'apps/multiplexer/app.json'), 'utf8'));
  if (manifest.id !== config.bundleId || manifest.app?.id !== config.bundleId) throw new Error('app.json identity differs from ios configuration; run bun scripts/configure-ios.ts to synchronize it before building');
}

type Profile = { Entitlements?: Record<string, any>; ExpirationDate?: string; ProvisionedDevices?: string[] };
export function validateDevelopmentProfile(profile: Profile, config: IOSConfig, product: 'app' | 'extension', device: string): void {
  const ent = profile.Entitlements ?? {};
  const id = product === 'app' ? config.bundleId : config.extensionId;
  const grants = (key: string, value: string) => Array.isArray(ent[key]) && ent[key].includes(value);
  if (ent['application-identifier'] !== `${config.teamId}.${id}` || ent['com.apple.developer.team-identifier'] !== config.teamId) throw new Error(`${product} profile does not match configured identity/team`);
  if (!grants('com.apple.security.application-groups', config.appGroup) || !(grants('keychain-access-groups', config.keychainGroup) || grants('keychain-access-groups', `${config.teamId}.*`))) throw new Error(`${product} profile does not grant configured App Group/Keychain group`);
  if (ent['get-task-allow'] !== true || !profile.ProvisionedDevices?.includes(device) || !(Date.parse(profile.ExpirationDate ?? '') > Date.now())) throw new Error(`${product} profile is expired or does not grant development access to this device`);
  if (product === 'app' && (ent['aps-environment'] !== 'development' || ent['com.apple.developer.usernotifications.communication'] !== true)) throw new Error('app profile must grant development APNs and Communication Notifications; regenerate APP_PROFILE');
}

export function readDevelopmentProfile(path: string): Profile {
  const decoded = Bun.spawnSync(['security', 'cms', '-D', '-i', path]);
  if (decoded.exitCode !== 0) throw new Error(`could not decode provisioning profile: ${path}`);
  return decodeDevelopmentProfile(decoded.stdout);
}

export function decodeDevelopmentProfile(profile: Uint8Array): Profile {
  // extract only JSON-compatible fields: certificates and dates elsewhere are not JSON values.
  const field = (key: string, format: string) => {
    const result = Bun.spawnSync(['plutil', '-extract', key, format, '-o', '-', '-'], { stdin: profile });
    if (result.exitCode !== 0) throw new Error(`profile is missing ${key}`);
    return result.stdout.toString().trim();
  };
  return { Entitlements: JSON.parse(field('Entitlements', 'json')), ProvisionedDevices: JSON.parse(field('ProvisionedDevices', 'json')), ExpirationDate: field('ExpirationDate', 'raw') };
}

if (import.meta.main) {
  try {
    const config = loadIOSConfig();
    const args = process.argv.slice(2);
    if (args.length === 1 && args[0] === '--shell') {
      checkIOSManifest(config);
      console.log([config.teamId, config.bundleId, config.extensionId, config.appGroup, config.sessionService, config.pushGateway].join('\n'));
    } else if (args.length === 3 && args[0] === '--preflight') {
      for (const [name, product] of [['APP_PROFILE', 'app'], ['EXTENSION_PROFILE', 'extension']] as const) {
        const path = process.env[name];
        if (!path || !existsSync(path)) throw new Error(`set ${name} to an existing development profile`);
        validateDevelopmentProfile(readDevelopmentProfile(path), config, product, args[1]);
      }
      const info = Bun.spawnSync(['plutil', '-extract', 'CFBundleIdentifier', 'raw', '-o', '-', resolve(args[2], 'Info.plist')]);
      if (info.exitCode !== 0 || info.stdout.toString().trim() !== config.bundleId) throw new Error('built app identity differs from configured bundleId');
    } else throw new Error('usage: bun scripts/ios-config.ts --shell | --preflight <device> <app>');
  } catch (error) { console.error(error instanceof Error ? error.message : String(error)); process.exitCode = 1; }
}
