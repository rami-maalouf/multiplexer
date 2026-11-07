# An entry animation on a node mounted with a navigation push waits for a later commit

**Status:** Open
**Systems:** runtime (iOS host), CSS `animation`
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-07

## What happened

A chat screen's composer row is now mounted in the same commit as the screen's navigation push. One button in the row has an entry animation:

```
button ... animation=(still ? "none" : "voiceIn 260ms cubic-bezier(.32,.72,0,1) both")
```

The row lays the button's 48-point slot out from the push's first frame, but the button stays invisible (the animation's first keyframe, held by `both`) until the next commit of the screen. In the app, that commit comes when the chat's messages load, 0.3 to 0.5 s later. Then the 260 ms animation plays. So the button seems to pop in late, although it was mounted on time.

With `prefers-reduced-motion: reduce` (the app then sets `animation="none"`), the button shows from the push's first frames. Before, when the row was mounted in the same commit as the messages, the animation played at once.

Cost: about 15 minutes, two probe recordings and frame sheets to tell the animation from the layout.

## What would help

- An animation that starts when its node is mounted, without waiting for a later commit, also when the node is mounted during a navigation push.
- If the wait is by design (for example, until the push's transition ends), a note in the animation docs, and the animation should start when the push ends, not at an unrelated later commit.

## Evidence

Seen on 2026-11-07 at exact2 `1baa95c770`, iOS Simulator (iPhone, dark), `agent ios --timing platform --touch platform`, recorded with `xcrun simctl io recordVideo`, cut to 60 fps.

- Motion on, chat A: push from frame 458; the slot is laid out, the button invisible from frame 467 to 491; messages arrive at frame 494, and the button fades in at 491 to 495.
- Motion on, chat B: push from frame 462; button invisible from 465 to 486; messages arrive at 489; fade-in at 489 to 495.
- Reduce Motion, chat C: the button is visible from frame 271, during the loading spinner (268 to 286).

In each case with motion, the start of the animation matches the next commit (the messages), not a fixed delay after the push.
