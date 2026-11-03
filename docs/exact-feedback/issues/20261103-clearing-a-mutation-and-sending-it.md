# Clearing a mutation and sending it in one action sends nothing

**Status:** Open
**Systems:** contract compiler, runner
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

An action reset two mutations, then sent one of them:

```
action openCamera
  cameraOpened = none
  cameraShot = none
  send cameraOpened = getUserMedia(video=true, videoConstraints=…)
  nav = push(nav, path("camera", openRoom))
```

The route opened, and the request never went: in the drive, `state pending` was `[]`,
`state cameraOpened` was `null`, and the logs had no `send cameraOpened` line. The compiler gave no
error or warning. With the two `= none` lines removed, the log showed `send cameraOpened:
media-capture.getUserMedia (native)` and the camera answered. Resetting another mutation in the
same action (`cameraFlipped = none` before `send cameraOpened`) works.

Cost: about 10 minutes and three drives.

## What would help

- The compiler refusing, or warning about, an assignment and a `send` to the same mutation in one
  action; or the `send` winning, as the order reads.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5).
