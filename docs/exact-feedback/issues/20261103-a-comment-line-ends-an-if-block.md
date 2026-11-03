# A comment line before an if block's first line ends the block

**Status:** Open
**Systems:** compiler
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A comment line between an `if` and the first line of its body, at the body's indentation, was
refused: "`if` needs a non-empty indented body".

```contract
if pictures
  // a list's row puts gaps and padding between its children
  row flex-wrap="wrap"
    ...
```

Moving the comment out of the block compiled. Cost: about 2 minutes.

## What would help

Comment lines allowed at a block's start, or the message naming the comment line as the cause.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5), a phone.
