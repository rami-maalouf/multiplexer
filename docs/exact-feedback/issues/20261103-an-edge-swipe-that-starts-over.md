# An edge swipe that starts over a pan handler goes to the pan, not back

**Status:** Open
**Systems:** iOS host, gestures
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

exact2's `messages` sample: a pushed chat with `navigationBar="none"` and a drawn Back, its
transcript a `scroll … pan=drag panrelease=release touch-action="pan-y"`. A real edge swipe in a
drive (`--touch platform`), `tap messages drag 320 0 from 4 450 press 100 over 400`, started over the
transcript: the log shows `pan view 157 (drag)` many times, and the chat stayed. The same swipe
from y 100, above the transcript, went back ("willShow 0 (animated, by the edge swipe)").

In `GesturePrecedenceIOS.swift`, a `swiperight` node's recognizer waits for the screen-edge pop
gesture to fail ("from the edge, back wins"); a `pan` handler's does not. In a hand-built iOS chat,
an edge swipe over the transcript goes back.

Cost: about 5 minutes, found while checking an edge swipe in a drive.

## What would help

- A horizontal `pan` waiting for the screen-edge pop gesture, as a `swiperight` does, or a doc line
  saying that a `pan` takes the edge swipe and how to keep the edge for Back.

## Evidence

Seen on 2026-11-03 at exact2 `574720f370`, iOS 26.5 simulator, in the `messages` sample.
