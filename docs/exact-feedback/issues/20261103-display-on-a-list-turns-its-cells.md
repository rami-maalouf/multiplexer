# display on a list turns its cells into a flex row, with no warning

**Status:** Open
**Systems:** compiler, apple host
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

To keep a chat list's scroll place while a search covered it, the list got
`display=(searching ? "none" : "flex")`. With the value `"flex"` (not searching), the list's rows
were laid out side by side, as a flex row: the list stopped being a list of cells. Nothing
warned, at compile time or in `check`.

```contract
list id="rooms" flex=1 min-height=0 display=(searching ? "none" : "flex")
  for r in rooms key=r.id
    link href=path("room", r.id)
      ...
```

The app used `opacity=(searching ? 0 : 1)` and `inert=searching` instead, which keep the list as
it was. Cost: about 5 minutes (a drive and a side-by-side screenshot).

## What would help

- A warning when a `list` gets `display` other than `none`, naming what it changes.
- A documented way to hide a box and keep its state (HTML's `hidden`, CSS's `visibility`).

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5), a phone.
