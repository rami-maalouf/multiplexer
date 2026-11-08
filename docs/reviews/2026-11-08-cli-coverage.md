# CLI coverage review

The first review task failed at its provider usage limit and produced no usable review.
A connected Sonnet 5.5 reviewer then performed two bounded manual reads: the expansion
against `89b4470`, and the fixes against `1bd0495`. These were independent source reviews,
not the full Compound Engineering multi-agent skill pipeline. The reviewer did not rerun
live accounts. The host read the manifest and complete argument tests separately, and owns
the release/unit/live results in the evidence files.

## Findings and resolution

1. A broken stdout pipe could terminate the CLI after server acceptance. A real-CLI
   regression with a readerless OS pipe failed before explicit SIGPIPE ignore. The fix
   allows EPIPE to reach the existing output-failure handler. The assertion requires the
   exact output-failure message, so an unrelated accepted-audit failure cannot pass it.
2. The encrypted-room scheduling test previously accepted any nonzero exit. It now checks
   the mutation-boundary error, validates the delayed-event response schema, checks no
   matching pending event exists, and checks decrypted room history for absence.
3. Scheduling reused a deadline computed before dry-run. Each command now computes a fresh
   future time immediately before launch.
4. The original policy existed only in memory during tests. Both runners now fsync a private,
   exclusive on-disk backup before replacement and retain it if restoration fails. Tests
   cover exact bytes, absence, stale backups and failed restoration. A follow-up regression
   caught a stale snapshot after failed snapshot sync; the original remains untouched and
   the helper removes its own failed snapshot before rethrowing.

The fix review found no blockers on extraction, cleanup or secret handling. Its remaining
bounded text-output behavior is documented in the coverage map. The review did not certify
whole-server/network outages, physical power-loss durability, real-account acceptance or
durable watch replay.
