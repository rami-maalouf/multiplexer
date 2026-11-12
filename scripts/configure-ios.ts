import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { loadIOSConfig, repositoryRoot, validateIOSConfig } from './ios-config.ts';

export function configureIOS(args: string[], root = repositoryRoot): void {
  let config;
  if (args.length === 0) config = loadIOSConfig(root);
  else {
    const values: Record<string, string> = {};
    const keys: Record<string, string> = { '--team-id': 'teamId', '--bundle-id': 'bundleId', '--push-gateway': 'pushGateway' };
    if (args.length !== 6) throw new Error('usage: bun scripts/configure-ios.ts [--team-id <id> --bundle-id <id> --push-gateway <https-url>]');
    for (let i = 0; i < args.length; i += 2) {
      const key = keys[args[i]];
      if (!key || key in values || !args[i + 1]) throw new Error('supply each configuration option exactly once');
      values[key] = args[i + 1];
    }
    config = validateIOSConfig(values);
  }
  const path = resolve(root, 'apps/multiplexer/app.json');
  const manifest = JSON.parse(readFileSync(path, 'utf8'));
  if (!manifest.app || typeof manifest.app !== 'object') throw new Error('app.json must contain an app object');
  const { teamId, bundleId, pushGateway } = config;
  // finish all validation and parsing before changing either file.
  if (args.length) writeFileSync(process.env.MUX_IOS_CONFIG ? resolve(process.env.MUX_IOS_CONFIG) : resolve(root, 'ios.config.local.json'), JSON.stringify({ teamId, bundleId, pushGateway }, null, 2) + '\n');
  if (manifest.id !== bundleId || manifest.app.id !== bundleId) {
    manifest.id = bundleId;
    manifest.app.id = bundleId;
    writeFileSync(path, JSON.stringify(manifest, null, 2) + '\n');
  }
}
if (import.meta.main) {
  try { configureIOS(process.argv.slice(2)); console.log('ios configuration validated; Exact manifest identity synchronized'); }
  catch (error) { console.error(error instanceof Error ? error.message : String(error)); process.exitCode = 1; }
}
