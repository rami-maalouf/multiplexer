# A drive cannot film a navigation's zoom: screenshot over starts after it ends

**Status:** Open
**Systems:** agent, Apple host
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

A chat app opens a photo in a full-screen viewer that zooms out of the photo's box (a route
with `navigationPresentation="fullscreen"` and `navigationSource="photo-<id>"`). After a
framework update I wanted to see that the zoom still runs:

1. `tap photo-<id>` then `screenshot <png> over 600 every 60 window`: every frame is the
   finished viewer, with the default delivery and with `--touch platform`.
2. A Simulator screen recording (`xcrun simctl io <udid> recordVideo`) made during the same
   drive shows a cut: the chat, one blank viewer frame, then the full picture, all within about
   20 ms. It seems a drive ends a navigation's transition at once.

The same `screenshot ... over ... every ... window` does film a swipe's spring back frame by
frame, so the difference is not obvious. Cost: about 10 minutes, and the zoom's motion was not
seen.

## What would help

- A drive option that lets a navigation's transition run in real time, so `screenshot over`
  films it, or a note in the agent's help that a drive settles transitions.

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0` (iOS Simulator). Related: exact2's `QUEUE.md`
entry "Film every presented frame on iOS and find the one-frame flash" (2026-10-25).
