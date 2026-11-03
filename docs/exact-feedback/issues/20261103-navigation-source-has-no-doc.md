# The zoom transition (`navigationSource`) has no doc an app can read

**Status:** Open
**Systems:** docs, `contract vocab`
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat app wanted its info page to zoom out of the chat bar's picture and name, as iOS 18's zoom
transition does. `bun exact.mjs contract vocab navigationSource` answers only "prop attribute,
prop navigationSource, str". `docs/` has no line that says how to use it: a grep finds it in
`agent-pitfalls.md` (by way of `fullscreen`), in two LLPs, and in the Apple host's
`ModalIOS.swift`.

What it takes came from the host's source and the LLPs:

- the presented route says `navigationPresentation="fullscreen"`;
- `navigationSource` is the HTML `id` of an element in the route under it;
- if the presented route has an element with the same `id`, the zoom lands there; else the
  whole route grows out of the source, and shrinks back into it on close.

Once known, it worked the first time. Cost: about 6 minutes.

## What would help

- The vocab card for `navigationSource` saying those three lines.
- A recipe line: "a detail that zooms out of the element tapped" (a photo viewer, a profile).

Both are pull request candidates.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`.
