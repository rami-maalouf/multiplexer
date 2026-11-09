#!/bin/bash
# package an existing production bundle without building or submitting it.
set -euo pipefail
export MUX_PACKAGE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec bun run - "$@" <<'JS'
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, symlinkSync, lstatSync, realpathSync } from 'node:fs';
import { resolve, join, isAbsolute, dirname, basename } from 'node:path';
import { pathToFileURL } from 'node:url';

const help = `Usage: scripts/package-macos.sh [--check|--dry-run|--prepare|--verify]
  --app PATH       existing Mux.app (required except for credential-only --check)
  --identity SHA1  valid Developer ID Application identity (or EXACT_DEVELOPER_ID)
  --out PATH       NEW output directory, required for --prepare
  --dmg PATH       existing notarized/stapled DMG, required for --verify
  --exact2 PATH    Exact checkout (or EXACT2, resolved relative to the app project)

Default: --check. Checks/dry-runs write nothing and make no network requests.
--prepare copies, signs with secure timestamps, creates ZIP and signed DMG candidates.
Timestamping contacts Apple's timestamp service. No mode submits or publishes.
--verify requires Developer ID, hardened runtime, tickets and Gatekeeper acceptance.
Candidates are NOT distributable until notarized, stapled and verified. See docs/mac-distribution.md.`;
const fail = message => { throw new Error(message); };
const run = (command, args, capture = false) => {
  const r = spawnSync(command, args, { encoding: 'utf8', stdio: capture ? 'pipe' : 'inherit' });
  if (r.status !== 0) fail(`${command} ${args[0]} failed (exit ${r.status ?? 'unavailable'})`);
  return `${r.stdout ?? ''}${r.stderr ?? ''}`;
};
const json = path => JSON.parse(readFileSync(path, 'utf8'));
try {
  const args = process.argv.slice(2), options = {};
  let mode = 'check', modeSet = false;
  for (let i = 0; i < args.length; i++) {
    const flag = args[i];
    if (flag === '--help' || flag === '-h') { console.log(help); process.exit(0); }
    if (['--check', '--dry-run', '--prepare', '--verify'].includes(flag)) {
      if (modeSet) fail('choose exactly one mode');
      mode = flag.slice(2); modeSet = true;
    } else if (['--app', '--identity', '--out', '--dmg', '--exact2'].includes(flag)) {
      if (!args[i + 1] || args[i + 1].startsWith('--')) fail(`${flag} needs a value`);
      if (options[flag]) fail(`${flag} was supplied twice`);
      options[flag] = args[++i];
    } else fail(`unknown option: ${flag}`);
  }
  if (process.platform !== 'darwin') fail('macOS is required');
  const root = process.env.MUX_PACKAGE_ROOT, project = join(root, 'apps/multiplexer');
  const framework = resolve(project, options['--exact2'] ?? process.env.EXACT2 ?? '../../../exact/exact2-multiplexer-integration');
  const signer = join(framework, 'host/apple/assets.mjs');
  if (!existsSync(signer)) fail(`Exact signing helper missing: ${signer}`);
  const manifest = json(join(project, 'app.json'));
  const id = 'com.ramimaalouf.multiplexer';
  if (manifest.app?.id !== id) fail('unexpected manifest app id');
  const identities = run('security', ['find-identity', '-v', '-p', 'codesigning'], true);
  const developerIDs = [...identities.matchAll(/\b([0-9A-F]{40})\s+"(Developer ID Application: [^"]+)"/g)];
  console.log(`Valid Developer ID Application identities: ${developerIDs.length}`);
  for (const [, hash, name] of developerIDs) console.log(`  ${hash} ${name}`);
  const requested = (options['--identity'] ?? process.env.EXACT_DEVELOPER_ID) || undefined;
  if (requested && !developerIDs.some(row => row[1] === requested)) fail('--identity must be the SHA-1 of a valid local Developer ID Application identity');
  const identity = requested ?? (developerIDs.length === 1 ? developerIDs[0][1] : null);
  if (!options['--app'] && mode !== 'check') fail('--app is required');
  let app, receipt;
  if (options['--app']) {
    app = resolve(options['--app']);
    if (!app.endsWith('.app') || !existsSync(app) || !lstatSync(app).isDirectory()) fail('--app must be an existing, non-symlink .app directory');
    const info = JSON.parse(run('plutil', ['-convert', 'json', '-o', '-', join(app, 'Contents/Info.plist')], true));
    if (info.CFBundleIdentifier !== id || info.CFBundlePackageType !== 'APPL') fail('bundle is not the Mux application');
    const executable = info.CFBundleExecutable;
    if (!executable || executable.includes('/') || executable === '.' || executable === '..') fail('invalid bundle executable');
    const binary = join(app, 'Contents/MacOS', executable);
    if (!run('file', ['-b', binary], true).includes('Mach-O')) fail('bundle executable is not Mach-O');
    receipt = json(join(app, 'Contents/Resources/receipt.json'));
    if (receipt.app?.id !== id || receipt.platform !== 'macos') fail('bundle receipt has the wrong identity or platform');
    if (receipt.build?.trust !== 'production' || receipt.build?.compat?.embedded?.trust !== 'production' || receipt.development) fail('bundle is not production-trust; build with mac --bundle --distribution first');
    if (receipt.composition !== 'embedded' || manifest.deploy?.store?.macos !== '0') fail('this packaging unit supports only embedded bundles with Mac updates disabled');
    console.log(`Production bundle: ${app}`);
  }
  if (mode !== 'verify' && !identity) fail('no unambiguous Developer ID Application identity; install one or select its SHA-1 (ad-hoc/Apple Development signing is not distribution)');
  if (mode === 'check' || mode === 'dry-run') {
    console.log('Local signing prerequisites pass. Notary credentials are not inspected or authenticated.');
    console.log('Would copy the supplied app, sign inside out with Exact, verify, create ZIP and signed DMG candidates. No files changed.');
    process.exit(0);
  }
  if (mode === 'verify') {
    if (!options['--dmg']) fail('--dmg is required for distribution verification');
    const dmg = resolve(options['--dmg']);
    for (const artifact of [app, dmg]) {
      run('codesign', ['--verify', '--deep', '--strict', artifact]);
      const signature = run('codesign', ['-d', '--verbose=4', artifact], true);
      if (!signature.includes('Authority=Developer ID Application:') || !signature.includes('Timestamp=')) fail('artifact lacks Developer ID authority or secure timestamp');
      if (artifact === app && !/flags=.*runtime/.test(signature)) fail('app lacks hardened runtime');
      run('xcrun', ['stapler', 'validate', artifact]);
    }
    run('spctl', ['--assess', '--type', 'execute', '--verbose=2', app]);
    run('hdiutil', ['verify', dmg]);
    run('spctl', ['--assess', '--type', 'open', '--context', 'context:primary-signature', '--verbose=2', dmg]);
    console.log('Supplied app and DMG passed local distribution verification. Verify a fresh downloaded install before sharing.');
    process.exit(0);
  }
  if (!options['--out'] || !isAbsolute(options['--out'])) fail('--out must be an absolute NEW directory');
  const destination = resolve(options['--out']);
  const out = join(realpathSync(dirname(destination)), basename(destination));
  const source = realpathSync(app);
  if (out === source || out.startsWith(source + '/')) fail('output must be outside the source app');
  if (existsSync(out)) fail('output already exists; choose a new directory (nothing is overwritten)');
  // import before creating output; Exact owns code order and entitlement derivation.
  const { signRelease } = await import(pathToFileURL(signer).href);
  mkdirSync(out); // exclusive creation also refuses a concurrent packager.
  const staged = join(out, 'Mux.app'), image = join(out, 'image');
  run('/usr/bin/ditto', [app, staged]);
  signRelease(staged, { compat: receipt.build.compat, manifest, identity, id, scratch: out });
  run('codesign', ['--verify', '--deep', '--strict', staged]);
  run('/usr/bin/ditto', ['-c', '-k', '--sequesterRsrc', '--keepParent', staged, join(out, 'Mux.zip')]);
  mkdirSync(image);
  run('/usr/bin/ditto', [staged, join(image, 'Mux.app')]);
  symlinkSync('/Applications', join(image, 'Applications'));
  const dmg = join(out, 'Mux.dmg');
  run('hdiutil', ['create', '-volname', 'Mux', '-srcfolder', image, '-format', 'UDZO', dmg]);
  run('codesign', ['--sign', identity, '--timestamp', dmg]);
  run('hdiutil', ['verify', dmg]);
  console.log(`CANDIDATES ONLY: ${out}\nNot notarized or stapled. Do not distribute. No submission or publishing performed.`);
} catch (error) {
  console.error(`package-macos: ${error.message}`);
  process.exit(1);
}
JS
