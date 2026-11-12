import { chmod, lstat, open, readFile, unlink, writeFile } from "node:fs/promises";

export const policyBackupPath = (path: string) => path + ".cli-test-backup.json";

export async function ensureNoPolicyBackup(path: string) {
  try { await lstat(policyBackupPath(path)); }
  catch (error: any) { if (error.code === "ENOENT") return; throw error; }
  throw new Error("a prior test-policy backup exists; preserve and restore it before running tests");
}

// retain the original outside process memory until restoration succeeds; never replace a stale backup.
export async function preservePolicy(path: string): Promise<() => Promise<void>> {
  const original = await readFile(path).catch((error: any) => { if (error.code === "ENOENT") return null; throw error; });
  const backup = await open(policyBackupPath(path), "wx", 0o600);
  try {
    await backup.writeFile(JSON.stringify({ version: 1, existed: original !== null, base64: original?.toString("base64") ?? null }) + "\n");
    await backup.sync();
  } catch (error) {
    // the original is untouched; remove only the snapshot this call created.
    await unlink(policyBackupPath(path)).catch(() => {});
    throw error;
  } finally { await backup.close(); }
  let restored = false;
  return async () => {
    if (restored) return;
    if (original !== null) {
      await writeFile(path, original, { mode: 0o600 }); await chmod(path, 0o600);
      const file = await open(path, "r");
      try { await file.sync(); } finally { await file.close(); }
    } else { await unlink(path).catch((error: any) => { if (error.code !== "ENOENT") throw error; }); }
    await unlink(policyBackupPath(path)); restored = true;
  };
}
