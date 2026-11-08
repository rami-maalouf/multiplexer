import { describe, expect, spyOn, test } from "bun:test";
import { mkdtemp, mkdir, open, readFile, rm, stat, unlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { ensureNoPolicyBackup, policyBackupPath, preservePolicy } from "./cli-test-policy";

async function fixture(work: (path: string) => Promise<void>) {
  const directory = await mkdtemp(join(tmpdir(), "mx-policy-test-"));
  try { await work(join(directory, "write-policy.json")); }
  finally { await rm(directory, { recursive: true, force: true }); }
}

describe("test policy preservation", () => {
  test("private snapshot survives replacement and restores exact bytes", () => fixture(async path => {
    const original = Buffer.from([0, 1, 10, 255]); await writeFile(path, original);
    const restore = await preservePolicy(path);
    const snapshot = JSON.parse(await readFile(policyBackupPath(path), "utf8"));
    expect(Buffer.from(snapshot.base64, "base64")).toEqual(original);
    expect(snapshot.existed).toBe(true);
    expect((await stat(policyBackupPath(path))).mode & 0o777).toBe(0o600);
    await writeFile(path, "temporary"); await restore();
    expect(await readFile(path)).toEqual(original);
    expect((await stat(path)).mode & 0o777).toBe(0o600);
    expect(await Bun.file(policyBackupPath(path)).exists()).toBe(false);
    await writeFile(path, "later operator edit"); await restore();
    expect(await readFile(path, "utf8")).toBe("later operator edit");
  }));
  test("initial absence is restored", () => fixture(async path => {
    const restore = await preservePolicy(path);
    expect(JSON.parse(await readFile(policyBackupPath(path), "utf8")).existed).toBe(false);
    await writeFile(path, "temporary"); await restore();
    expect(await Bun.file(path).exists()).toBe(false);
    expect(await Bun.file(policyBackupPath(path)).exists()).toBe(false);
  }));
  test("stale backups cannot be overwritten", () => fixture(async path => {
    await ensureNoPolicyBackup(path); await writeFile(path, "original");
    const restore = await preservePolicy(path), bytes = await readFile(policyBackupPath(path));
    await expect(ensureNoPolicyBackup(path)).rejects.toThrow("prior test-policy backup");
    await expect(preservePolicy(path)).rejects.toThrow();
    expect(await readFile(policyBackupPath(path))).toEqual(bytes);
    expect(await readFile(path, "utf8")).toBe("original"); await restore();
  }));
  test("failed restoration retains the snapshot", () => fixture(async path => {
    await writeFile(path, "original"); const restore = await preservePolicy(path);
    await unlink(path); await mkdir(path);
    await expect(restore()).rejects.toThrow();
    const snapshot = JSON.parse(await readFile(policyBackupPath(path), "utf8"));
    expect(Buffer.from(snapshot.base64, "base64").toString()).toBe("original");
  }));
  test("failed snapshot sync leaves the original policy and no stale partial backup", () => fixture(async path => {
    await writeFile(path, "original");
    const handle = await open(path, "r"), prototype = Object.getPrototypeOf(handle);
    await handle.close();
    const sync = spyOn(prototype, "sync").mockRejectedValueOnce(new Error("injected snapshot sync failure"));
    try { await expect(preservePolicy(path)).rejects.toThrow("injected snapshot sync failure"); }
    finally { sync.mockRestore(); }
    expect(await readFile(path, "utf8")).toBe("original");
    expect(await Bun.file(policyBackupPath(path)).exists()).toBe(false);
  }));
});
