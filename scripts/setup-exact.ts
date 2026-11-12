import { existsSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';

const revision = '94b8671f70fe2e25b307a40e7fce66dc27c9f802';
const expectedTree = 'bc7d0c19b7e492d6a198c3b7d0b044b5dff9a05d';

export function setupExact(args: string[]): void {
  if (args.length !== 1 || args[0].startsWith('-')) throw new Error('usage: bun scripts/setup-exact.ts <new-exact-directory>');
  const destination = resolve(args[0]);
  if (existsSync(destination)) throw new Error('destination already exists; choose a new directory to preserve existing work');
  const patch = resolve(import.meta.dir, '../patches/exact/mux-integration.patch');
  if (!existsSync(patch)) throw new Error('missing bundled Exact integration patch');
  mkdirSync(destination, { recursive: true });
  const git = (...argv: string[]) => {
    const result = Bun.spawnSync(['git', '-C', destination, ...argv], { stdout: 'pipe', stderr: 'pipe' });
    if (result.exitCode !== 0) throw new Error(`git ${argv[0]} failed: ${result.stderr.toString().trim()}`);
    return result.stdout.toString().trim();
  };
  git('init');
  git('remote', 'add', 'origin', 'https://github.com/expo/exact.git');
  git('fetch', '--depth=1', 'origin', revision);
  git('checkout', '--detach', 'FETCH_HEAD');
  git('apply', '--index', patch);
  if (git('write-tree') !== expectedTree) throw new Error('the prepared Exact source does not match the validated integration; checkout retained for inspection');
  git('reset', '--quiet');
  console.log(`prepared Exact at ${destination}`);
  console.log(`source tree verified: ${expectedTree}`);
  console.log('the bundled integration is an uncommitted patch on the pinned upstream revision');
  console.log('next: in the prepared directory, run bun scripts/exact.mjs setup');
}

if (import.meta.main) {
  try { setupExact(process.argv.slice(2)); }
  catch (error) { console.error(error instanceof Error ? error.message : String(error)); process.exitCode = 1; }
}
