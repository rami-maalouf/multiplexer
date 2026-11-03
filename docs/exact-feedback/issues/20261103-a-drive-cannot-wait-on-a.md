# A drive cannot wait on a list item found by its key

**Status:** Open
**Systems:** agent driver
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat app's list is a resource of rows (`roomList.rooms`, each with an `id`, a `name` and a
`lastMessage`). The drive had to wait until one known row changed: another device archived or
deleted a message while the list was open. `clock until state` takes one path and one literal:

```
clock until state roomList.rooms.length > 0 within 20000
  -> clock until state <path> == <literal> within <ms> (the literal is JSON ...), not `... > 0 ...`
```

So the waits were written by index and by count: `roomList.rooms.0.lastMessage == "..."` and
`roomList.rooms.length == 40`. Both misled: other writers of the same test account changed the
list's order and length during the drive, so the first wait timed out on another row ("was
\"Sticker\"") and the second compared a count that was already off by one. The working way was to
dump `state roomList.rooms --full` before and after a `clock +45000 real`, then find the row by
its id with a script outside the drive.

Cost: about 15 minutes and four drives.

## What would help

- A path that finds a list item by a key, in `state`, `expect state` and `clock until state`:
  `roomList.rooms[id="!abc"].lastMessage`.
- Or a few comparisons beyond `==`: `!=`, `>`, `contains`.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5). The spec's `clock until`
form (`llp/1012-agent-api-v1.spec.md`) is `clock until state <path> == <literal> within <ms>`.
