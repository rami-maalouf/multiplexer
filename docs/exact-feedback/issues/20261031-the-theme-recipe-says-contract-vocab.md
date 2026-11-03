# the theme recipe says contract vocab answers a role, and it does not

**Status:** Open
**Systems:** docs, contract vocab
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-31

## What happens

`docs/recipes/theme.md` says "`contract vocab -exact-label` answers a role". It does not:
`bun exact.mjs contract vocab -exact-label` and `contract vocab -exact-fill` both answer
"is not a tag, an attribute, a standard function, a recipe or a pattern".

I wanted the list of colour roles, to find an opaque grey for a chat bubble (the tail of
an iOS bubble overlaps its body, so a translucent fill such as `-exact-fill` shows a seam).
`docs <words>` did not list them either. I found the role names only by searching the
framework's source (the Linux host's `presenter/contrast.rs`). There is no opaque grey
near the Messages bubble's grey, so the app added a tamber token. Cost: about 10 minutes.

## What would help

`contract vocab <role>` answering a role (its colour on each host, light and dark, and
whether it is opaque), and one page that lists every role.

## Evidence

Seen on 2026-10-31 at exact2 `1bc4c36cb7`. Related: finding "vocab gives no attributes or
values" (2026-10-27).

## Pull request (2026-11-02)

https://github.com/ccheever/exact2/pull/1342 (fixes part of it): the theme recipe says that `contract vocab color` lists the roles. A lookup of a role's colour per host is a design question.
