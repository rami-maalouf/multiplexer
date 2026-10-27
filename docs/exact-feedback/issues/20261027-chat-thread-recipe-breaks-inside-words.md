# The `chat-thread` recipe's bubble uses `overflow-wrap="anywhere"`, which `verify ios` reports

**Status:** Open
**Systems:** docs (`docs/recipes/chat-thread.md`), `verify`
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

A transcript copied from the recipe (`text m.body … overflow-wrap="anywhere"`) gave one
`verify ios` finding: `breaks app.contract:<line> text overflow-wrap="anywhere": breaks
inside words (Octo/ber); wrap between words (the default) or give the row room`. With
`overflow-wrap="break-word"`, `verify ios` was clean. The recipe's note says that
`anywhere` breaks a long word (a URL) whichever box bounds the bubble, as UIKit does.
Cost: about 2 minutes.

## What would help

The recipe and `verify` agreeing: `break-word` in the recipe, or `verify` accepting
`anywhere` in a bubble with a `max-width`.

## Evidence

Seen on 2026-10-27. The recipe still has `overflow-wrap="anywhere"` at `cee509ac82`.
