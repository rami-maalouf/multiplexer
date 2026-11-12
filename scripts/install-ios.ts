import { existsSync } from 'node:fs';
import { resolve } from 'node:path';

// exact installs its bare bundle first. always package and reinstall before declaring success.
export function builtApp(output: string): string {
  const matches = [...output.matchAll(/^host\/apple: (\/.+\.app) on .+$/gm)];
  const path = matches.at(-1)?.[1];
  if (!path || !existsSync(path)) throw new Error('the ios build did not report an existing app bundle; push packaging was not run');
  return path;
}

export async function installIOS(args: string[]): Promise<void> {
  if (args.length !== 2 || !['--sim', '--device'].includes(args[0]) || !args[1] || args[1].startsWith('-')) {
    throw new Error('usage: bun scripts/install-ios.ts --sim <udid> | --device <udid>');
  }
  const [mode, target] = args;
  if (mode === '--device') {
    for (const name of ['APP_PROFILE', 'EXTENSION_PROFILE']) {
      const path = process.env[name];
      if (!path || !existsSync(path)) throw new Error(`set ${name} to an existing development provisioning profile before building`);
    }
    const decoded = Bun.spawnSync(['security', 'cms', '-D', '-i', process.env.APP_PROFILE!]);
    const converted = Bun.spawnSync(['plutil', '-convert', 'json', '-o', '-', '-'], { stdin: decoded.stdout });
    let granted = false;
    try { granted = JSON.parse(converted.stdout.toString()).Entitlements?.['com.apple.developer.usernotifications.communication'] === true; } catch {}
    if (!granted) throw new Error('enable Communication Notifications for the app identifier and regenerate APP_PROFILE before installing sender avatars');
  }
  const root = resolve(import.meta.dir, '..');
  const build = Bun.spawn(['bun', 'exact.mjs', 'ios', ...(mode === '--device' ? ['--device', '--phone', target] : ['--sim', target])],
    { cwd: resolve(root, 'apps/multiplexer'), stdout: 'pipe', stderr: 'pipe' });
  const relay = async (stream: ReadableStream<Uint8Array>, sink: NodeJS.WriteStream) => {
    const decoder = new TextDecoder();
    let output = "";
    for await (const chunk of stream) {
      const text = decoder.decode(chunk, { stream: true });
      output += text;
      sink.write(text);
    }
    return output + decoder.decode();
  };
  const [stdout, stderr, exit] = await Promise.all([relay(build.stdout, process.stdout), relay(build.stderr, process.stderr), build.exited]);
  if (exit !== 0) throw new Error(`ios build failed (${exit}); no push-ready installation was produced`);
  const app = builtApp(`${stdout}\n${stderr}`);
  const packaged = Bun.spawn([resolve(root, 'scripts/add-notification-extension.sh'), mode, target, app],
    { cwd: root, stdout: 'inherit', stderr: 'inherit' });
  if (await packaged.exited !== 0) throw new Error('push packaging failed; the installed app is not push-ready');
  console.log('push-ready app installed; open it to register notifications');
}

if (import.meta.main) {
  installIOS(process.argv.slice(2)).catch(error => { console.error(error.message); process.exitCode = 1; });
}
