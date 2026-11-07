# layout shows no scroll state for a windowed list

**Status:** Open
**Systems:** agent (iOS drive), layout
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-07

## What happened

`agent ios ... "layout <list>"` printed `scroll viewport 0,0 of 0,0` for a windowed list: no content offset, no content size, no insets. A drive could not show what the keyboard did to the list. I added temporary `NSLog` lines to the host, rebuilt (a few minutes for each Swift edit) and read them with `xcrun simctl spawn <udid> log stream`.

Cost: about 20 minutes.

## What would help

`layout` naming a scroller's offset, content size, and content and adjusted insets.

## Evidence

Seen on 2026-11-07 at exact2 `8e547ca606`, iOS Simulator, a chat transcript (a windowed `list`).
