# A data module answer refused for its 100 ms turn shows as a stale page; only logs name it

**Status:** Open
**Systems:** runner, agent, docs
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A data-module source marked the searched words in 60 messages' text, with a Unicode
`normalize("NFD")` and a regex for each character. It took 272 ms of CPU, over the 100 ms
budget for one turn, and was refused. On screen the resource kept its previous answer: an empty
page, with no error and no spinner. `state found.messages` showed `[]`. Only `logs` named it:

```
`loadSearch` took 272.0 ms of its own (CPU) time (272.3 ms of wall), over the 100 ms budget for
one turn; a long loop can `await scheduler.yield()` every few thousand items to go on in a new turn
```

That message was exact and named the fix. The app folds only non-ASCII characters, and only at
word starts. Cost: about 10 minutes (two drives before reading the logs).

## What would help

- The drive's step output, or `state <resource>`, naming a refused answer (as it names a
  diagnostic for a task due later).
- The data-module docs saying that a turn has 100 ms of CPU, and roughly how fast the engine
  is next to a browser's.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5), a phone.
