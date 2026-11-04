# A derive's expression cannot go on to a second line, and the refusal does not say so

**Status:** Open
**Systems:** compiler
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-04

## What happens

In a members file, a `derive` with a long expression went on to a second, more indented line:

```
  derive picks = roomList.rooms.filter(r => …)
    .map(r => Candidate(id=r.id, …))
```

It was refused at the second line: "expected a section, found an indented block". A view's
attributes may go on to further indented lines, so the same shape in a derive looked fine. The
message did not name the derive or say that its expression must stay on one line. I joined it into
one long line.

Cost: about 2 minutes.

## What would help

- Continuation lines for a derive's expression, as a view's attributes have.
- Or the refusal saying that a `derive` takes one line, at the derive.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`.
