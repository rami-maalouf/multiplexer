# `path()` takes only a literal route name, so a choice of two routes needs two pushes

**Status:** Open
**Systems:** compiler (`route-unknown`)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A grid of photos and videos opens a tile in the photo viewer or the video viewer:

```contract
action showMedia(id: string, isVideo: bool)
  nav = push(nav, path(isVideo ? "video" : "photo", openRoom, id))
```

The build refused: "`path()` needs a string-literal route name as its first argument". The
message is clear; the workaround is an `if`/`else` with one push each.

Cost: about 1 minute.

## What would help

`path()` taking a conditional of two literals (both are checked routes), or the message showing
the `if`/`else` form.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`.
