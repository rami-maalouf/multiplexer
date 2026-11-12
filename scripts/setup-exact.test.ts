import { expect, test } from 'bun:test';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { setupExact } from './setup-exact.ts';

test('Exact setup rejects incomplete arguments and preserves existing checkouts', () => {
  for (const args of [[], ['--force'], ['one', 'two']]) expect(() => setupExact(args)).toThrow('usage:');
  const dir = mkdtempSync(join(tmpdir(), 'mux-existing-exact-'));
  const file = join(dir, 'work.txt');
  writeFileSync(file, 'unfinished work');
  try {
    expect(() => setupExact([dir])).toThrow('destination already exists');
    expect(readFileSync(file, 'utf8')).toBe('unfinished work');
  } finally { rmSync(dir, { recursive: true }); }
});
