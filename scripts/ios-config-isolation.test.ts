import { expect, test } from 'bun:test';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

test('configuration tests preserve an operator override and pass with it configured', () => {
  const root = mkdtempSync(join(tmpdir(), 'mux-operator-config-'));
  const path = join(root, 'operator.json');
  const content = JSON.stringify({ teamId: 'OPERATOR01', bundleId: 'org.operator.mux', pushGateway: 'https://push.operator.test/_matrix/push/v1/notify' }) + '\n';
  writeFileSync(path, content);
  try {
    const result = Bun.spawnSync([process.execPath, 'test', join(import.meta.dir, 'ios-config.test.ts')],
      { env: { ...process.env, MUX_IOS_CONFIG: path } });
    expect(readFileSync(path, 'utf8')).toBe(content);
    expect(result.exitCode, result.stderr.toString()).toBe(0);
  } finally { rmSync(root, { recursive: true, force: true }); }
});
