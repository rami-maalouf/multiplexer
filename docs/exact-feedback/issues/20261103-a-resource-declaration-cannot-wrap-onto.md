# A `resource` declaration cannot wrap onto a second line, and its refusal does not say so

**Status:** Open
**Systems:** Contract compiler (syntax)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A long `resource` line was wrapped before its `as`:

```contract
resource chatFound = loadSearch(session.userId, chatSearching and infoRoom != "", chatQuery.trim(), chatKind, noChats, infoRoom)
  as shape SearchFound else empty()
```

The refusal: "expected `as`, found end of line". A `derive` wrapped the same way, just under it,
got a helpful refusal: "an indented line that starts with an operator continues the line above,
and a declaration is one line: ... wrap the whole expression in parentheses". Parentheses do not
fit the resource's `as shape ... else ...`, so the only form is one line of about 150
characters.

Cost: about 1 minute, and a line past the file's usual width.

## What would help

- The resource's refusal saying that a declaration is one line.
- A resource that can continue after its call (an indented `as shape ...` line).

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5).
