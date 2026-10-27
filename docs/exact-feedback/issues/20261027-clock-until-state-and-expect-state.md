# `clock until state` and `expect state` take different path forms

**Status:** Open
**Systems:** agent (clock until), authored tests (expect state), docs
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

`docs/start-here.md` teaches the `expect state` path with a space after a list index:
`expect state lib.notes.0 .title == "Milk"`. A drive step written the same way,
`"clock until state thread.messages.19 .body == \"x\" within 45000"`, was refused with the
grammar alone: "clock until state <path> == <literal> within <ms> (the literal is JSON …),
not `…`". The form `clock until` takes is `thread.messages.19.body`, with no space.

Cost: about 3 minutes, and one wasted drive that had signed in to a real server.

## What would help

- Both steps accepting both forms.
- Or the refusal naming the fix: "write the path without spaces: thread.messages.19.body".

## Evidence

Seen on 2026-10-27 at exact2 `cee509ac82`, on iOS. `clock until state thread.messages.19.body == "x" within 1000`
was accepted and answered "thread.messages has no field \"19\" (it is [])".
