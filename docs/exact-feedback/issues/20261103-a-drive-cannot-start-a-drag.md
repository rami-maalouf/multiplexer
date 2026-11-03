# A drive cannot start a drag at a point, so it cannot make an edge swipe

**Status:** Open
**Systems:** agent
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A pushed screen says `navigationBar="none"` and draws its own Back (`button id="back"`, the
root's `navigationBack`). The docs say the edge swipe still goes back and presses that control.
To see it in a drive, under `--touch platform --timing platform`:

```
tap root at 2 450 drag 320 0
-> unknown word "drag"; this form takes at <x> <y>, modifiers <Shift+Control+Alt+Meta>
```

`tap <target> drag <dx> <dy>` starts at the target's middle, and no target's middle is within
the 20 points of the screen's edge where UIKit's edge pan starts. So the edge swipe was not
driven; only the agent's `back`, which presses the same control, was.

Cost: about 3 minutes.

## What would help

`tap at <x> <y> drag <dx> <dy>` (or `tap root at <x> <y> drag ...`) under `--touch platform`, or
an `edge-swipe` step that drags from the leading edge.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0` (iOS Simulator, iOS 26.5). Related: finding "A drive
cannot fire swiperight, and a real touch misses a link row".
