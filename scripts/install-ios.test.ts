import { expect, test } from 'bun:test';
import { builtApp, installIOS } from './install-ios.ts';
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
