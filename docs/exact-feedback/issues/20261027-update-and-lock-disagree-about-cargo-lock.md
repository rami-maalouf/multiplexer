# After `update`, `lock` reports "no changes" for a `Cargo.lock` that `update` just rewrote

**Status:** Open
**Systems:** `exact.mjs update`, `exact.mjs lock`
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

After `bun exact.mjs update`, a command said: "Cargo.lock: does not match the app
manifests; run `bun exact.mjs lock`". `bun exact.mjs lock` then said "current; no
changes", but git showed `Cargo.lock` changed (2 lines). `update` had already written it.
Cost: about 2 minutes.

## What would help

`update` saying that it rewrote the lock, or `lock` not reporting "no changes" for a file
that `update` just changed.

## Evidence

From the app's diary entry for the update to `cee509ac82`.

## Seen again at `1bc4c36cb7` (2026-10-31)

`update` printed "Cargo.lock: does not match the app manifests; run `bun exact.mjs lock`",
and `lock` then said "current; no changes". `update` also prints "app.contract: every file
names what it uses", which reads like a problem; it is the module-scope check passing.

## Seen again at `ed43ad09a0` (2026-11-02)

The same two messages after updating from `1bc4c36cb7`: `update` removed one line from
`Cargo.lock` and said it "does not match the app manifests; run `bun exact.mjs lock`", and
`lock` said "current; no changes".
