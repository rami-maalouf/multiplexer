# a list of plain numbers warns lower-key-position for its only key

**Status:** Open
**Systems:** compiler
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A voice message's waveform is a list of numbers, each a bar's height, drawn as a row of bars:

```contract
for b, i in bars key=i
  view width=2 height=(3 + b * 23) border-radius=1 background-color=ink
```

The build warns three times (once for each place the component is used):
`[lower-key-position] this key reads `i#37`, the row's position: after a row is inserted or
removed before others, their keys name other records, ...; key by something the record keeps,
such as its id`. Here the position is the only identity a bar has: the list is never inserted
into, its length is fixed, and its values repeat, so a value cannot be the key either. Each
build (and each drive) repeats the three warnings, and there is no way to say "the position is
the identity".

`verify ios` counts these warnings as problems ("verify: 4 problems (4 findings; the tests
passed)"), so the app cannot reach a clean run with them. The workaround: the data module turns
each number into a record with its place as an id (`{ id: "0", level: 0.4 }`), and the loop keys
by `b.id`. The key is the same position as before; only the warning is gone.

Cost: about 2 minutes, then three or four warnings in every build of the session, then about 10
minutes for the workaround once `verify` counted them.

## What would help

No warning when the list's items are plain numbers or strings with no record to key by, or a
way to mark a positional key as meant (for example `key=position`). Which one is a design
question for the Exact team.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0` (`contract build`, `agent ios`).
