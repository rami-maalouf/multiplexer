# A virtualized list asks reachstart once while its top stays in reach

**Status:** Open
**Systems:** virtualized list, docs
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat transcript (`list virtualized=true scroll-start="end" reachstart=loadOlder`) opens at its
"New" line with `scrollIntoView(…, block="center")`. While it moves there, the app holds older loads
back (older rows added above could move the line out of view). The list fired `reachstart` once, at
its first frame, during that move; the app held it back. Then the list never fired again, though
the reader scrolled to the top: its top row had stayed within the reach margin, and the logs showed
only the one `reachstart`. The chat stayed at its last 20 messages.

`docs/reference.md` ("Intersection visibility") says when the events fire, not that a list asks
once until its edge row leaves the margin. `QUEUE.md` notes that re-arming needs the band measured.

The app now keeps a flag when it holds a request back, and loads when the line is placed.

Cost: about 15 minutes and three builds.

## What would help

- A line in the reference: `reachstart` fires once as the edge comes within reach, and again only
  after the edge row has left the margin, so an app that cannot serve it then should remember it.
- Or the event firing again when the list's content changes while the edge is still in reach.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS 26.5 simulator.
