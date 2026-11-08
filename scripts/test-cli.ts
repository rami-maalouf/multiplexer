// live cli acceptance as the test account only; hold mx-lock matrixcore around this script.
import { join } from "node:path";
import { homedir } from "node:os";
import { chmod, readFile, writeFile, unlink } from "node:fs/promises";

const root = join(import.meta.dir, "..");
const binary = join(root, "cli/.build/release/mx");
const base = join(homedir(), "Library/Application Support/com.ramimaalouf.multiplexer.cli");
const policyPath = join(base, "write-policy.json");
const auditPath = join(base, "audit.jsonl");
const user = "@test1:ramimaalouf.com";
let checks = 0;
let sessionCreated = false, policyReplaced = false;
function expect(value: unknown, description: string) {
  if (!value) throw new Error(description);
  checks++;
}
async function run(args: string[], stdin?: string, success = true) {
  const process = Bun.spawn([binary, ...args], { stdin: stdin === undefined ? "ignore" : new Blob([stdin]), stdout: "pipe", stderr: "pipe" });
  const timer = setTimeout(() => process.kill(), 120_000);
  const [out, err, code] = await Promise.all([new Response(process.stdout).text(), new Response(process.stderr).text(), process.exited]);
  clearTimeout(timer);
  expect(success ? code === 0 : code !== 0, `unexpected result for ${args[0]}: ${err}`);
  return out;
}
function lines(text: string) { return text.trim().split("\n").filter(Boolean).map(line => JSON.parse(line)); }
const existing = await readFile(policyPath).catch(error => { if (error.code === "ENOENT") return null; throw error; });
const auditBefore = await readFile(auditPath).catch(error => { if (error.code === "ENOENT") return Buffer.alloc(0); throw error; });
if (auditBefore.length && auditBefore[auditBefore.length - 1] !== 10) throw new Error("existing audit log has an incomplete final record");
let watch: ReturnType<typeof Bun.spawn> | undefined;
try {
  const identity = Bun.spawn([binary, "whoami"], { stdout: "pipe", stderr: "pipe" });
  await new Response(identity.stdout).text();
  if (await identity.exited === 0) throw new Error("refusing to replace an existing CLI session; sign out first");
  const secret = Bun.spawn(["security", "find-generic-password", "-s", "multiplexer-test-account", "-a", user, "-w"], { stdout: "pipe", stderr: "pipe" });
  const password = await new Response(secret.stdout).text();
  expect(await secret.exited === 0 && password.trim(), "test password unavailable");
  await run(["login", user, "--password-stdin"], password);
  sessionCreated = true;
  const cold = JSON.parse(await run(["chats", "--json", "--limit", "1000"]));
  const warm = JSON.parse(await run(["chats", "--json", "--limit", "1000"]));
  console.log("cold/warm rank comparison (observational; SDK hydration is asynchronous): " +
    (JSON.stringify(cold.map(x => x.id)) === JSON.stringify(warm.map(x => x.id)) ? "equal" : "changed"));
  expect(Array.isArray(cold) && Array.isArray(warm), "chats did not return JSON arrays");
  const room = cold.find(x => x.name === "Multiplexer two-person test");
  expect(room, "test room unavailable");
  const other = cold.find(x => x.id !== room.id);
  expect(other, "second room needed for denial proof");
  await writeFile(policyPath, JSON.stringify({ version: 1, accounts: { [user]: [room.id] } }), { mode: 0o600 });
  policyReplaced = true;
  await chmod(policyPath, 0o600);
  const marker = `cliaccept${Date.now()}`;
  await run(["send", other.id, marker], undefined, false);
  await run(["send", room.id, marker, "--typo"], undefined, false);
  await run(["send", room.id, marker, "--dry-run"]);
  let messages = lines(await run(["read", room.id, "--limit", "20"]));
  expect(!messages.some(x => x.text === marker), "dry run sent a message");
  const confirmed = lines(await run(["send", room.id, marker]));
  expect(confirmed[0]?.eventId?.startsWith("$"), "send did not return a server event id");
  const recent = JSON.parse(await run(["chats", "--json", "--limit", "1"]));
  expect(recent[0]?.lastMessage === marker, "warm newest synthetic message not first");
  messages = lines(await run(["read", "Multiplexer two-person test", "--limit", "20"]));
  const sent = messages.find(x => x.text === marker);
  expect(sent?.eventId && sent.sender === user && Array.isArray(sent.reactions), "sent message not read with expected JSONL fields");
  const reacted = lines(await run(["react", room.id, sent.eventId, "ok"]));
  expect(reacted[0]?.eventId?.startsWith("$"), "reaction did not return server event id");
  messages = lines(await run(["read", room.id, "--limit", "20"]));
  expect(messages.find(x => x.eventId === sent.eventId)?.reactions.some(x => x.key === "ok" && x.isMine), "reaction absent after process exit");
  await run(["mark-read", room.id]);
  const at = new Date(Date.now() + 2500).toISOString().replace(/\.\d{3}Z$/, "Z");
  await run(["later", room.id, `${marker}later`, "--at", at]);
  await Bun.sleep(3000);
  messages = lines(await run(["read", room.id, "--limit", "20"]));
  expect(messages.some(x => x.text === `${marker}later`), "scheduled message did not arrive");
  const found = lines(await run(["search", marker, "--chat", room.id]));
  expect(found.some(x => x.type === "search-status"), "search has no index-scope status");
  expect(found.some(x => x.text === marker), "search did not find synthetic message");
  await run(["recover", "--key-stdin"], "wrong recovery key\n", false);
  watch = Bun.spawn([binary, "watch", "--chat", room.id], { stdout: "pipe", stderr: "pipe" });
  const reader = watch.stdout.getReader();
  let output = "";
  async function until(match: (values: any[]) => boolean) {
    const end = Date.now() + 60_000;
    while (Date.now() < end) {
      let timer: ReturnType<typeof setTimeout> | undefined;
      let next: ReadableStreamReadResult<Uint8Array>;
      try {
        next = await Promise.race([reader.read(), new Promise<never>((_, reject) => {
          timer = setTimeout(() => reject(new Error("watch timed out")), 60_000);
        })]);
      } finally { clearTimeout(timer); }
      if (next.done) throw new Error("watch stopped before expected output");
      output += new TextDecoder().decode(next.value);
      const complete = output.slice(0, output.lastIndexOf("\n") + 1);
      if (match(lines(complete))) return;
    }
    throw new Error("watch timed out");
  }
  await until(values => values.some(x => x.type === "ready"));
  await run(["chats"], undefined, false);
  const live = `${marker}live`;
  const sender = Bun.spawn([join(root, "scripts/send-test-message.sh"), live], { stdout: "pipe", stderr: "pipe" });
  await new Response(sender.stdout).text();
  const senderError = await new Response(sender.stderr).text();
  expect(await sender.exited === 0, `test sender failed: ${senderError}`);
  await until(values => values.some(x => x.text === live));
  expect(lines(output).filter(x => x.text === live).length === 1, "watch duplicated a message");
  watch.kill(); await watch.exited; watch = undefined;
  await reader.cancel();
  const auditAfter = await readFile(auditPath);
  expect(auditAfter.subarray(0, auditBefore.length).equals(auditBefore), "existing audit records changed");
  const audit = lines(auditAfter.subarray(auditBefore.length).toString("utf8"));
  expect(audit.every(x => x.account === user && [room.id, other.id].includes(x.roomId)), "audit appended an unexpected account or room");
  expect(audit.some(x => x.outcome === "denied" && x.roomId === other.id), "current run denial audit missing");
  expect(audit.some(x => x.outcome === "dry-run" && x.roomId === room.id), "current run dry-run audit missing");
  for (const action of ["send", "react", "mark-read", "later"]) {
    const started = audit.find(x => x.action === action && x.outcome === "started");
    expect(started && audit.some(x => x.operation === started.operation && x.action === action && x.outcome === "accepted"),
      "current run write lacks matching started/accepted audit records: " + action);
  }
  expect(!JSON.stringify(audit).includes(marker), "audit exposed message content");
  console.log(`cli acceptance passed (${checks} checks); JSON chats, warm newest order, JSONL read/search, send/react/read receipt/later, deny/dry-run/audit, live watch and process lock`);
} finally {
  watch?.kill(); if (watch) await watch.exited;
  try {
    if (sessionCreated) await run(["logout"]).catch(error => { console.error("cleanup: logout failed"); throw error; });
  } finally {
    if (policyReplaced && existing === null) await unlink(policyPath).catch(error => { if (error.code !== "ENOENT") throw error; });
    else if (policyReplaced && existing !== null) await writeFile(policyPath, existing, { mode: 0o600 });
  }
}
