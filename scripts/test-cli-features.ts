// run under scripts/mx-lock.sh matrixcore; credentials and recovery keys stay in private pipes.
import { join } from "node:path";
import { homedir } from "node:os";
import { chmod, readFile, writeFile, unlink } from "node:fs/promises";
import { ensureNoPolicyBackup, preservePolicy } from "./cli-test-policy";

const root = join(import.meta.dir, "..");
const mx = join(root, "cli/.build/release/mx");
const probeBinary = join(root, "cli/.build/release/CLIProbe");
const policy = join(homedir(), "Library/Application Support/com.ramimaalouf.multiplexer.cli/write-policy.json");
const user = "@test1:ramimaalouf.com", peer = "@test2:ramimaalouf.com";
const marker = `clicoverage${Date.now()}`;
type Result = { feature: string; status: "passed" | "blocked" | "failed"; reason?: string };
const results: Result[] = [];
function check(value: unknown, message: string): asserts value { if (!value) throw new Error(message); }
async function feature(name: string, work: () => Promise<void>) {
  try { await work(); results.push({ feature: name, status: "passed" }); console.log(`pass: ${name}`); }
  catch { results.push({ feature: name, status: "failed", reason: "assertion or operation failed; inspect the named scenario" }); throw new Error(`feature failed: ${name}`); }
}
const jsonl = (text: string): any[] => text.trim().split("\n").filter(Boolean).map(x => JSON.parse(x));
async function command(args: string[], input?: string, success = true) {
  const process = Bun.spawn([mx, ...args], { stdin: input === undefined ? "ignore" : new Blob([input]), stdout: "pipe", stderr: "pipe" });
  const timer = setTimeout(() => process.kill("SIGKILL"), 150_000);
  try {
    const [out, error, code] = await Promise.all([new Response(process.stdout).text(), new Response(process.stderr).text(), process.exited]);
    check(success ? code === 0 : code !== 0, `unexpected command exit: ${args[0]}`);
    return { out, error, code };
  } finally { clearTimeout(timer); }
}
async function password(account: string) {
  const child = Bun.spawn(["security", "find-generic-password", "-s", "multiplexer-test-account", "-a", account, "-w"], { stdout: "pipe", stderr: "ignore" });
  const value = await new Response(child.stdout).text();
  check(await child.exited === 0 && value.trim(), "test credential unavailable");
  return value.trim();
}
class LineReader {
  reader: ReadableStreamDefaultReader<Uint8Array>; buffer = ""; decoder = new TextDecoder();
  constructor(stream: ReadableStream<Uint8Array>) { this.reader = stream.getReader(); }
  async line(timeout = 150_000): Promise<any> {
    const end = Date.now() + timeout;
    while (!this.buffer.includes("\n")) {
      let timer: ReturnType<typeof setTimeout> | undefined;
      try {
        const part = await Promise.race([this.reader.read(), new Promise<never>((_, reject) => {
          timer = setTimeout(() => reject(new Error("stream timeout")), Math.max(1, end - Date.now()));
        })]);
        check(!part.done, "stream ended"); this.buffer += this.decoder.decode(part.value, { stream: true });
      } finally { clearTimeout(timer); }
    }
    const index = this.buffer.indexOf("\n"), line = this.buffer.slice(0, index); this.buffer = this.buffer.slice(index + 1);
    return JSON.parse(line);
  }
}
let probe: ReturnType<typeof Bun.spawn> | undefined, probeLines: LineReader | undefined;
async function rpc(command: string, fields: Record<string, unknown> = {}) {
  check(probe && probeLines, "fixture unavailable");
  probe.stdin.write(JSON.stringify({ command, ...fields }) + "\n"); probe.stdin.flush();
  const value = await probeLines.line(); check(!value.error, "fixture operation failed"); return value;
}
let watcher: ReturnType<typeof Bun.spawn> | undefined;
async function startWatch(args: string[] = []) {
  watcher = Bun.spawn([mx, "watch", ...args], { stdout: "pipe", stderr: "ignore" });
  const lines = new LineReader(watcher.stdout);
  check((await lines.line()).type === "ready", "watch did not baseline before ready"); return lines;
}
async function stopWatch() { if (watcher) { watcher.kill("SIGKILL"); await watcher.exited; watcher = undefined; } }
async function waitMessage(lines: LineReader, text: string) {
  const end = Date.now() + 60_000;
  while (Date.now() < end) { const value = await lines.line(end - Date.now()); if (value.text === text) return value; }
  throw new Error("watch missed expected message");
}
let server = "";
async function api(token: string | undefined, method: string, path: string, body?: unknown) {
  const response = await fetch(server + "/_matrix/client/v3/" + path, { method,
    headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(30_000) });
  const result = await response.json(); check(response.ok, `test server returned ${response.status}`); return result;
}
let ownerToken: string | undefined, peerToken: string | undefined, since: string | undefined;
const receipts = new Map<string, string>();
async function sync(room: string) {
  const filter = JSON.stringify({ room: { rooms: [room], timeline: { limit: 10 } } });
  const data = await api(peerToken, "GET", `sync?timeout=0&filter=${encodeURIComponent(filter)}${since ? `&since=${encodeURIComponent(since)}` : ""}`);
  since = data.next_batch;
  for (const event of data.rooms?.join?.[room]?.ephemeral?.events ?? []) {
    if (event.type !== "m.receipt") continue;
    for (const [eventId, types] of Object.entries(event.content)) {
      for (const account of Object.keys((types as any)["m.read"] ?? {})) receipts.set(account, eventId);
    }
  }
}
async function eventually(work: () => Promise<boolean>, timeout = 60_000) {
  const end = Date.now() + timeout;
  do { if (await work()) return; await Bun.sleep(500); } while (Date.now() < end);
  throw new Error("expected remote state did not arrive");
}
let sessionCreated = false, completed = false;
let closedOutputObservation: { exitCode: number; serverAccepted: boolean; retryWarning: boolean } | undefined;
let restorePolicy: (() => Promise<void>) | undefined;
let cliDevice = "";
let probeDevice = "";
await ensureNoPolicyBackup(policy);
try {
  await feature("signed-out commands and help", async () => {
    check((await command(["help"])).out.includes("mx read"), "missing command help");
    check((await command(["whoami"], undefined, false)).error.includes("signed out"), "existing session or lock; refusing to replace it");
    for (const args of [["read", "missing"], ["search", "query"], ["send", "missing", "text"], ["recover", "--key-stdin"]]) {
      await command(args, args[0] === "recover" ? "wrong\n" : undefined, false);
    }
  });
  const firstPassword = await password(user), secondPassword = await password(peer);
  const discovery = await (await fetch("https://ramimaalouf.com/.well-known/matrix/client")).json();
  server = discovery["m.homeserver"].base_url.replace(/\/$/, "");
  ownerToken = (await api(undefined, "POST", "login", { type: "m.login.password", identifier: { type: "m.id.user", user }, password: firstPassword, initial_device_display_name: "Mux CLI coverage observer" })).access_token;
  peerToken = (await api(undefined, "POST", "login", { type: "m.login.password", identifier: { type: "m.id.user", user: peer }, password: secondPassword, initial_device_display_name: "Mux CLI receipt observer" })).access_token;
  probe = Bun.spawn([probeBinary], { stdin: "pipe", stdout: "pipe", stderr: "ignore" });
  probeLines = new LineReader(probe.stdout);
  probe.stdin.write(JSON.stringify({ user, password: firstPassword }) + "\n"); probe.stdin.flush();
  const ready = await probeLines.line();
  check(ready.status === "ready" && ready.deviceId, "fixture not ready"); probeDevice = ready.deviceId;
  const existing = (await rpc("rooms")).rooms;
  async function room(name: string, encrypted = false) {
    return existing.find((x: any) => x.id.startsWith("!") && x.name === name)?.id ?? (await rpc("create", { name, encrypted })).roomId;
  }
  const a = await room("CLI coverage A"), b = await room("CLI coverage B"), encrypted = await room("CLI coverage encrypted", true);
  const duplicates = existing.filter((x: any) => x.name === "CLI coverage duplicate").map((x: any) => x.id);
  while (duplicates.length < 2) duplicates.push((await rpc("create", { name: "CLI coverage duplicate" })).roomId);
  const recovery = await rpc("recovery");
  const history = marker + "history";
  await rpc("send", { roomId: encrypted, text: history });
  if (recovery.key) await rpc("backup");
  await feature("login, identity and persistent session", async () => {
    await command(["login", user, "--password-stdin"], firstPassword + "\n"); sessionCreated = true;
    const identity = (await command(["whoami"])).out;
    check(identity.includes(user), "wrong session identity");
    cliDevice = /device ([^,]+)/.exec(identity)?.[1] ?? "";
    check(cliDevice, "device identity missing");
    await command(["login", user, "--password-stdin"], firstPassword + "\n", false);
  });
  restorePolicy = await preservePolicy(policy);
  await writeFile(policy, JSON.stringify({ version: 1, accounts: { [user]: [a, b, encrypted] } }), { mode: 0o600 });
  await chmod(policy, 0o600);
  await feature("missing/malformed/unsupported/wrong-account policies deny real sends", async () => {
    const allowed = await readFile(policy);
    try {
      await unlink(policy); await command(["send", a, marker + "denied"], undefined, false);
      for (const value of ["{broken", JSON.stringify({ version: 2, accounts: { [user]: [a] } }), JSON.stringify({ version: 1, accounts: { [peer]: [a] } })]) {
        await writeFile(policy, value, { mode: 0o600 }); await command(["send", a, marker + "denied"], undefined, false);
      }
      const events = await api(ownerToken, "GET", `rooms/${encodeURIComponent(a)}/messages?dir=b&limit=20`);
      check(!events.chunk.some((x: any) => x.content?.body === marker + "denied"), "denied write reached server");
    } finally { await writeFile(policy, allowed, { mode: 0o600 }); }
  });
  await feature("closed stdout reports confirmed acceptance without inviting a retry", async () => {
    const text = marker + "closedoutput";
    // create a real pipe with no reader; stream cancellation alone may keep bun's pipe open.
    const launcher = "import os,signal,sys; r,w=os.pipe(); os.close(r); os.dup2(w,1); os.close(w); signal.signal(signal.SIGPIPE, signal.SIG_DFL); os.execv(sys.argv[1], sys.argv[1:])";
    const child = Bun.spawn(["uv", "run", "--no-project", "python", "-c", launcher, mx, "send", a, text], { stdin: "ignore", stdout: "pipe", stderr: "pipe" });
    await child.stdout.cancel();
    const timer = setTimeout(() => child.kill("SIGKILL"), 150_000);
    let error: string, code: number;
    try { [error, code] = await Promise.all([new Response(child.stderr).text(), child.exited]); }
    finally { clearTimeout(timer); }
    const events = await api(ownerToken, "GET", `rooms/${encodeURIComponent(a)}/messages?dir=b&limit=10`);
    const serverAccepted = events.chunk.some((x: any) => x.content?.body === text);
    const outputFailure = error.includes("server accepted the write but output failed");
    closedOutputObservation = { exitCode: code, serverAccepted, retryWarning: outputFailure && error.includes("do not resend") };
    check(serverAccepted, "closed-output send was not accepted by server");
    check(code === 1 && outputFailure && error.includes("do not resend"), `closed-output error contract failed with exit ${code}`);
  });
  await feature("chat formats, limits and ambiguous names", async () => {
    const chats = JSON.parse((await command(["chats", "--json", "--limit", "2"])).out);
    check(chats.length <= 2 && chats.every((x: any) => Array.isArray(x.roomIds)), "chat JSON contract");
    check((await command(["chats"])).out.length > 0, "plain chat list empty");
    check((await command(["read", "CLI coverage duplicate"], undefined, false)).error.includes("ambiguous"), "duplicate name silently selected");
    await command(["read", "no such coverage chat"], undefined, false);
  });
  await feature("wrong and empty recovery input are refused", async () => {
    await command(["recover", "--key-stdin"], "wrong recovery key\n", false);
    await command(["recover", "--key-stdin"], "\n", false);
  });
  if (recovery.key) {
    await feature("valid recovery decrypts older history on a fresh CLI device", async () => {
      const before = jsonl((await command(["read", encrypted])).out);
      check(before.some(x => x.waitingForKey), "fresh CLI already had historical keys; test precondition not met");
      await command(["recover", "--key-stdin"], recovery.key + "\n");
      await eventually(async () => jsonl((await command(["read", encrypted])).out).some(x => x.text === history && !x.waitingForKey));
    });
  } else results.push({ feature: "valid recovery decrypts older history on a fresh CLI device", status: "blocked", reason: recovery.blocked });
  await feature("encrypted confirmed sends are encrypted on the server", async () => {
    const text = marker + "encrypted";
    const sent = jsonl((await command(["send", encrypted, text])).out)[0];
    const raw = await api(ownerToken, "GET", `rooms/${encodeURIComponent(encrypted)}/event/${encodeURIComponent(sent.eventId)}`);
    check(raw.type === "m.room.encrypted" && !JSON.stringify(raw).includes(text), "encrypted send exposed plaintext");
    await eventually(async () => (await rpc("read", { roomId: encrypted })).messages.some((x: any) => x.text === text));
    const refusal = await command(["later", encrypted, marker + "noschedule", "--at", new Date(Date.now() + 60_000).toISOString()], undefined, false);
    check(refusal.error.includes("write failed or its result is unknown"), "encrypted schedule failed before reaching its mutation boundary");
    const pendingResponse = await fetch(server + "/_matrix/client/unstable/org.matrix.msc4140/delayed_events", {
      headers: { Authorization: `Bearer ${ownerToken}` }, signal: AbortSignal.timeout(30_000) });
    check(pendingResponse.ok, "could not independently inspect scheduled events");
    const pending = await pendingResponse.json();
    check(Array.isArray(pending.delayed_events), "scheduled-event response schema missing");
    check(!pending.delayed_events.some((x: any) => x.room_id === encrypted && x.content?.body === marker + "noschedule"), "encrypted schedule reached server");
    check(!(await rpc("read", { roomId: encrypted })).messages.some((x: any) => x.text === marker + "noschedule"), "refused scheduled text was delivered");
  });
  await feature("JSONL round-trip, chronology and read limit", async () => {
    const text = marker + ' quote " slash \\ newline\nsecond line é';
    await command(["send", a, text]);
    const read = jsonl((await command(["read", a, "--limit", "3"])).out);
    check(read.length <= 3 && read.some(x => x.text === text), "message text did not round-trip");
    check(read.every((x, i) => !i || read[i - 1].timestamp <= x.timestamp), "read is not chronological");
  });
  await feature("merged read/search and folded-name resolution", async () => {
    await command(["send", a, marker + " alpha"]); await command(["send", b, marker + " beta"]);
    const merged = (await rpc("merge", { rooms: [a, b], name: "CLI coverage A" })).chatId;
    await eventually(async () => JSON.parse((await command(["chats", "--json"])).out).some((x: any) => x.id === merged));
    const read = jsonl((await command(["read", "CLI coverage A", "--limit", "100"])).out);
    check(read.some(x => x.text === marker + " alpha") && read.some(x => x.text === marker + " beta"), "merge did not expand both rooms");
    await eventually(async () => {
      const found = jsonl((await command(["search", marker, "--chat", merged])).out);
      return found.some(x => x.text === marker + " alpha") && found.some(x => x.text === marker + " beta");
    });
    await command(["send", merged, "refused"], undefined, false);
  });
  // independent peer sync observes receipts; test fixture and CLI must not generate them implicitly.
  try { await api(ownerToken, "POST", `rooms/${encodeURIComponent(a)}/invite`, { user_id: peer }); } catch { /* peer may already be joined. */ }
  await api(peerToken, "POST", `join/${encodeURIComponent(a)}`, {});
  await sync(a);
  let event = "";
  await feature("read/search/watch leave read receipts unchanged", async () => {
    const baseline = receipts.get(user);
    await command(["read", a]); await command(["search", marker, "--chat", a]);
    const stream = await startWatch(["--chat", a]);
    event = (await api(peerToken, "PUT", `rooms/${encodeURIComponent(a)}/send/m.room.message/${crypto.randomUUID()}`, { msgtype: "m.text", body: marker + "receipt" })).event_id;
    await waitMessage(stream, marker + "receipt"); await stopWatch();
    await sync(a); await Bun.sleep(1000); await sync(a);
    check(receipts.get(user) === baseline, "read-only commands sent a read receipt");
    await command(["mark-read", a, "--dry-run"]); await sync(a);
    check(receipts.get(user) === baseline, "mark-read dry-run sent a receipt");
  });
  await feature("explicit mark-read reaches an independent device", async () => {
    await command(["mark-read", a]);
    await eventually(async () => { await sync(a); return receipts.get(user) === event; });
  });
  await feature("cross-room reactions and disallowed dry-runs fail closed", async () => {
    const otherEvent = (await rpc("send", { roomId: b, text: marker + "otherroom" })).eventId;
    await command(["react", a, otherEvent, "ok"], undefined, false);
    await command(["send", duplicates[0], "refused", "--dry-run"], undefined, false);
    const reaction = jsonl((await command(["react", a, event, "ok"])).out)[0];
    check(reaction.eventId?.startsWith("$"), "reaction confirmation missing");
  });
  await feature("watch crash releases lock and restart has no historical replay", async () => {
    await startWatch(["--chat", a]);
    await command(["read", a], undefined, false); await stopWatch();
    check((await command(["whoami"])).out.includes(user), "watch crash lost session or lock");
    const stream = await startWatch(["--chat", a]);
    await api(peerToken, "PUT", `rooms/${encodeURIComponent(a)}/send/m.room.message/${crypto.randomUUID()}`, { msgtype: "m.text", body: marker + "restart" });
    const next = await stream.line(60_000);
    check(next.text === marker + "restart", "watch replayed history after restart"); await stopWatch();
  });
  await feature("merged-scope watch receives both physical rooms", async () => {
    const stream = await startWatch(["--chat", "CLI coverage A"]);
    await rpc("send", { roomId: b, text: marker + "mergewatch" });
    check((await waitMessage(stream, marker + "mergewatch")).roomId === b, "merged watch used synthetic room id"); await stopWatch();
  });
  await feature("unscoped watch works with merged rooms", async () => {
    const stream = await startWatch(); await rpc("send", { roomId: b, text: marker + "globalwatch" });
    await waitMessage(stream, marker + "globalwatch"); await stopWatch();
  });
  await feature("watch burst remains bounded and read recovers current history", async () => {
    const stream = await startWatch(["--chat", b, "--limit", "2"]);
    for (let i = 0; i < 5; i++) await rpc("send", { roomId: b, text: `${marker}burst${i}` });
    const events: string[] = [];
    while (true) {
      const message = await stream.line(60_000);
      check(message.text?.startsWith(marker + "burst"), "watch emitted stale burst history");
      events.push(message.eventId);
      if (message.text === marker + "burst4") break;
    }
    check(new Set(events).size === events.length && events.length <= 5, "watch duplicated burst events");
    await stopWatch();
    const messages = jsonl((await command(["read", b, "--limit", "10"])).out);
    check(Array.from({ length: 5 }, (_, i) => messages.some(x => x.text === `${marker}burst${i}`)).every(Boolean), "read did not recover burst history");
  });
  await feature("scheduled confirmation, delayed delivery and invalid times", async () => {
    await command(["later", a, "invalid", "--at", "yesterday"], undefined, false);
    await command(["later", a, marker + "drylater", "--at", new Date(Date.now() + 20_000).toISOString(), "--dry-run"]);
    const at = new Date(Date.now() + 20_000).toISOString();
    const accepted = jsonl((await command(["later", a, marker + "scheduled", "--at", at])).out)[0];
    check(accepted.status === "scheduled" && accepted.delayId, "scheduled confirmation missing");
    await eventually(async () => jsonl((await command(["read", a, "--limit", "20"])).out).some(x => x.text === marker + "scheduled"));
    check(!jsonl((await command(["read", a])).out).some(x => x.text === marker + "drylater"), "scheduled dry-run reached server");
  });
  await feature("logout revokes the device and repeated logout is harmless", async () => {
    await command(["logout"]); sessionCreated = false;
    await command(["whoami"], undefined, false); await command(["logout"]);
    const devices = await api(ownerToken, "GET", "devices");
    check(!devices.devices.some((x: any) => x.device_id === cliDevice), "CLI device remains on server after logout");
  });
  completed = results.every(x => x.status === "passed");
} finally {
  await stopWatch();
  const cleanup: string[] = [];
  if (sessionCreated) { try { await command(["logout"]); } catch { cleanup.push("CLI logout failed"); } }
  if (probe) {
    try { await rpc("quit"); } catch { cleanup.push("fixture logout failed"); }
    probe.stdin.end();
    const timer = setTimeout(() => { cleanup.push("fixture required forced shutdown"); probe?.kill("SIGKILL"); }, 15_000);
    try { await probe.exited; } finally { clearTimeout(timer); }
  }
  if (ownerToken && probeDevice) {
    try {
      const devices = await api(ownerToken, "GET", "devices");
      check(!devices.devices.some((x: any) => x.device_id === probeDevice || x.device_id === cliDevice), "owned CLI or fixture device remains");
    } catch { cleanup.push("owned device absence not confirmed"); }
  }
  for (const token of [ownerToken, peerToken]) { if (token) { try { await api(token, "POST", "logout", {}); } catch { cleanup.push("observer logout failed"); } } }
  if (restorePolicy) { try { await restorePolicy(); } catch { cleanup.push("prior policy restoration failed; backup retained"); } }
  const report = { date: "2026-11-08", suite: "CLI feature integration", completed, results, cleanup, closedOutputObservation,
    limits: ["real-account credentials not requested or used", "cold ordering remains a known hydration limitation", "watch is best effort, not durable replay", "test rooms/merges and newly enabled test recovery are retained; no server data deleted"] };
  await writeFile(join(root, "tasks/evidence/cli-feature-coverage-20261108.json"), JSON.stringify(report, null, 2) + "\n");
  check(cleanup.length === 0, "test cleanup incomplete; inspect evidence");
}
check(completed, "feature suite has blocked or incomplete verification; inspect evidence");
console.log(`feature scenarios: ${results.filter(x => x.status === "passed").length} passed, ${results.filter(x => x.status === "blocked").length} blocked`);
