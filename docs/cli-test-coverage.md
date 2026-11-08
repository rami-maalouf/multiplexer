# CLI verification

The CLI has two complementary suites: deterministic tests of the production boundaries and
live scenarios that run the release executable against the test accounts. Counts below are
test cases or named scenarios, not individual polling iterations.

```sh
./scripts/test-cli.sh
```

The single entry point runs all checks and holds the shared test-account lock for both live
suites. To run a specific layer:

```sh
swift test --package-path cli
swift build --package-path cli -c release
./scripts/mx-lock.sh matrixcore cli-features -- bun scripts/test-cli-features.ts
./scripts/mx-lock.sh matrixcore cli-smoke -- bun scripts/test-cli.ts
```

## Command coverage

| Command or behavior | Deterministic proof | Live proof |
|---|---|---|
| help, unknown commands, arguments and flags | every command's valid and invalid argument forms, duplicates and limits | help and signed-out errors |
| login / whoami | full user id and stdin requirements | new device, identity, persistent session, refusal to replace a session |
| chats | visible filtering before limit, text/JSON fields, merged room ids | both formats and limit |
| room selection | ids win; only visible exact names; duplicate names list ids | duplicate names fail; merged visible name resolves despite folded component |
| read | flags, reactions, JSON escaping, chronological merged limit | quoted/multiline text round-trip, limit, both merged rooms |
| search | descending ordering and combined result limit | messages in both merged rooms; local-index scope remains explicit |
| recover | stdin required; secrets not accepted in arguments | wrong/empty key refused; fresh device initially waiting for key, then decrypts historical text after valid recovery |
| send | policy, durable write ordering and failure outcomes | confirmed event id, another process reads text; encrypted room produces an encrypted server event and another device decrypts it |
| react | shared write guard, event id input and outcome | server event id; visible after sender exit in smoke suite; cross-room event refused |
| mark-read | explicit write guard and dry-run | independent peer observes no receipt from read/search/watch or dry-run, then observes the exact event receipt after mark-read |
| later | past/malformed times refused; fractional ISO timestamps accepted; audit precedes success output | dry-run absent, scheduled id returned and message delivered; encrypted room refused |
| watch | baseline, deduplication, timestamp boundary, lagging snapshot retry, removed rooms, bounded loss/replay and same-timestamp limitations | scoped, merged and unscoped streams; lock contention; SIGKILL release; restart without historical replay; burst recovered through read |
| logout | syntax and no implicit mutation paths | device absent from server afterward; signed-out identity and repeated logout |

## Failure and safety coverage

- Every write action uses the same tested policy/audit transaction. Missing, malformed,
  unsupported-version, wrong-account and wrong-room policies deny mutation. Dry-run cannot
  invoke its mutation closure. The live suite independently checks denied text did not reach
  the server.
- A durable started record precedes mutation and accepted precedes success output. Tests
  inject server failure, unknown outcome, started/accepted audit failure, short writes,
  interrupted writes and failed fsync. Real temporary files exercise append/permissions,
  partial-tail preservation, symlink refusal and output-file failure. Disk failure after
  server acceptance reports acceptance and says not to resend.
- A real child process holds the lock. Another process is refused; SIGKILL releases the lock.
  A symlink lock is refused and the directory uses private permissions.
- Live credentials and recovery keys travel through private pipes. CLIProbe refuses every
  account except the two designated test users. It never resets or deletes an existing
  backup. A newly enabled test backup is retained with its key in the private Keychain
  service `multiplexer-cli-test-recovery` so later runs can recover safely.
- The runner refuses an existing CLI session, restores the prior write policy, signs out its
  CLI, fixture and observer devices, and reports cleanup failure as failure. Test rooms,
  fixture merges and newly enabled test recovery remain for repeatable tests; server data is
  not deleted.
  Blocked verification also causes a nonzero suite exit; it cannot silently count as a pass.

## Results and limits

The initial expanded run passed 58 XCTest entries: 57 substantive cases and one subprocess
helper. The live suite passed 18 named scenarios, with zero blocked. The recorded live result
is in `tasks/evidence/cli-feature-coverage-20261108.json`.

Two defects were reproduced and fixed: output failure after server acceptance now explicitly
says not to resend, and scheduling accepts fractional-second ISO timestamps. Their regression
tests failed before the fixes and pass afterward.

This covers every implemented command and the named failure boundaries, not every possible
environmental failure. SDK outage/partition behavior is represented at the mutation boundary;
the suite does not turn off the Mac's network or fault the production server. Encryption is
proved on Matrix test rooms, not on real WhatsApp or Instagram conversations. No real account
was accessed.

Cold recency ordering remains an SDK hydration limitation. Watch is explicitly best effort:
bursts beyond its snapshot, same-timestamp events, clock skew and reconnect gaps can lose
messages; dedupe eviction or reset can replay a message within the time window. Tests
characterize these bounds and do not certify durable delivery. Attachment metadata and reply
context remain absent from the text output. These limitations are not marked fixed by passing
the suites.
