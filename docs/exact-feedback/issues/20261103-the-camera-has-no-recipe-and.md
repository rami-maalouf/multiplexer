# The camera has no recipe, and records no video

**Status:** Open
**Systems:** docs, packages
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat app adds a built-in camera to its composer: a full-screen viewfinder, a shutter, a flip,
and the photo joins the next message. `docs/` names `@exact/camera` only in the native-views
recipe's first line and in `start-here`'s table ("a map, the camera"). The way to use it came from
five places: the package's `exact.json`, its conformance fixture (`test/fixture/app.contract`), its
person checklist, its drive suite (`test/drives.mjs`: the agent's back camera, `--permission
camera=granted`, the photo at `app:/tmp/camera/1.jpg`) and the photo editor app.

Things no doc says, found by reading or by trying:

- Open a track with `getUserMedia(video=true)`, show it with `exact-camera srcObject=track`, take
  the photo with `takePhoto(track=…)`, and `stopTrack` when the screen closes, or the camera stays
  on.
- `getPhotoCapabilities(track="")` (before the camera opens) is refused `NotFoundError`, which
  `verify` reports in every test as "resource … was refused once". The app read the flash from the
  track's `capabilities.torch` instead.
- A drive's camera: `--permission camera=granted`, the agent's card as the picture, `prefer
  extension camera.picture=…` for another.
- No video: `@exact/recording` records the microphone only (`audioBitsPerSecond`, no video track),
  and `@exact/camera` takes stills. A camera that also records a video, as the phone's own camera
  does, needs a native module of the app's own.

Cost: about 15 minutes of reading, and one `verify` round for the capabilities.

## What would help

- A `camera` recipe of about 40 lines: open, view, shutter, stop, the refused state with
  `openURL("app-settings:")`, and how a drive grants the camera and names the picture.
- `getPhotoCapabilities` answering its zero for an empty track, as an unset handle, or the recipe
  saying to ask it only with a track.
- Video from the camera in `@exact/recording` (a video track to a file), or a line in the recipe
  that it is not there.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5), with the agent's camera.
