# A contract fn has no unit test

**Status:** Open
**Systems:** contract tests, docs
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat app's message menu shows Edit for 15 minutes after sending on one network, and nothing
limits it on the others. That rule is a pure function of the network, the message's time and
the clock, and it wanted a unit test with a few times on each side of the limit.

A contract `fn` has no such test:

- `docs "unit test"` answered with the toolchain's own `bun test ./scripts/` line;
  `docs "test a fn"` found nothing.
- `contract vocab test` pointed to the tests recipe, whose tests drive the UI from a fresh
  launch with empty storage. Here the rule needs a signed-in account and a chat on that
  network, which a fresh launch does not have.

Workaround: the rule went into a TypeScript module tested with `bun test`. The data module
adds each message's "until" times to its answer, and the contract keeps a one-line
`fn within(until: number, now: number): bool` that repeats the module's comparison, because a
contract cannot call a TypeScript function. The rule now lives in two languages.

Cost: about 6 minutes.

## What would help

`test` blocks for a contract's `fn`s (arguments and the expected value), run by `test` and
`verify`; or, until then, a line in the tests recipe saying where a pure rule should live so it
can be unit tested.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`.

### Additional evidence, 2026-11-14

A rule choosing which links go to another app (a link's host against a list of sites) was written
as contract `fn`s, because an action calls it. No authored test could check it: there is no
expression step, and a test starts signed out, so no chat with a link is reachable. Drives were
the only check. About 4 minutes reading the test grammar.
