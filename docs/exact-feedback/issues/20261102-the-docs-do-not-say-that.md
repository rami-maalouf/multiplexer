# The docs do not say that a picked file's copy has another name than Picked.name

**Status:** Open
**Systems:** docs, media picker
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

`input type="file"` delivers `Picked` records: `name` is the file's own name ("Trip
plan.pdf"), and `path` is the copy under `app:/tmp/picked/`, whose file name is another one
(`app:/tmp/picked/1-3.pdf`). The docs (`contract-for-agents.md` around 1375, `reference.md`
around 2010) say "copies under `app:/tmp/picked/`" but not that the copy's file name differs
from `name`.

A chat app passed `path` to a third-party library that names an upload after its file.
The file reached the other person as "1-3.pdf". Nothing is wrong in Exact, but the doc led
to a wrong send that only a drive showed.

Cost: one wrong send seen in a drive, and about 10 minutes for a fix in the native module
(a hard link with the picked name, in a folder of its own).

## What would help

One sentence where `Picked` is described: "the copy's file name is not `name`; send or
save it under `name`".

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0`, `agent ios`, with a held Files picker answered
by `type @<id> <path>`.

## Pull request (2026-11-02)

https://github.com/ccheever/exact2/pull/1342 (fixes it): the guides say that the copy at `path` has another name, and to show or upload it under `name`.
