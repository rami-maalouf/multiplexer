# match on a string is refused as "expected some, found a string", which does not say that match takes only an option

**Status:** Open
**Systems:** Contract compiler (syntax)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

`fn filterName(f: string): string = match f { case "unread" => "Unread", case _ => "All" }`
fails with "expected `some`, found a string" at each string pattern. I had read `match` as
a general switch (the card shows it on options only, but says nothing against other
values). The fix is a chain of conditionals: `f == "unread" ? "Unread" : (f == "groups" ?
"Groups" : "All")`.

Cost: about 3 minutes.

## What would help

The refusal saying "`match` takes an option (`some`, `none`); to choose by a value, write
`x == "a" ? ... : ...`".

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0` (`bun exact.mjs contract build app.contract
--json --errors-only`).
