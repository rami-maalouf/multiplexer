# A drive's view of a video: `state media` is not in the agent's help, AVKit's controls show only under a real touch, and a video under the agent never takes the audio session

**Status:** Open
**Systems:** agent (iOS), docs (contract-for-agents, "Sound, MIDI and media"; ios-driving)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat plays a video message full screen with `video path controls=true autoplay=true
playsinline=true`, and a drive was to prove that it plays, with its controls and its sound.

- Screenshots showed the video's frames but never AVKit's controls, also after `tap
  <video testId>`: the drive's tap is an activation of the node, not a touch on AVKit's view.
  Under `--touch platform` the same tap showed them (scrubber, ±10 s, full screen, AirPlay).
- To learn whether it played, the docs' media section gives events and `currentTime`, but not how
  a drive reads the player. `state media` (each video's renderer, `paused`, `currentTime`,
  `muted`, `volume`) is in LLP 1042 only; `agent --help all` does not name it.
- The controls' speaker showed a slash although `state media` said `muted: false, volume: 1`.
  `VideoModule.swift` explains it: under the agent a video never holds the audio session
  (`audible = !ExactEnv.agentMode && ...`), so the app's `audio_session: "playback"` is not taken.
  Right for a drive, but nothing says so, and a drive cannot show that a video has sound.

Cost: about 10 minutes (three drives, then grepping the LLP and the host).

## What would help

- `state media` in `agent --help all` and in the media section of contract-for-agents, with one
  line: under the agent a video keeps the ambient session, so its sound is not proved by a drive.
- The ios-driving recipe saying that AVKit's own controls answer only a `--touch platform` tap.

These are pull request candidates.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0` on the iOS 26.5 Simulator: `state media` read
`"renderer":"AVKit","paused":false,"muted":false,"volume":1`; screenshots
with and without `--touch platform`.

## Pull request (2026-11-03)

https://github.com/ccheever/exact2/pull/1366 (fixes it): `agent --help all` and contract-for-agents name `state media` (Apple), say that under the agent a video takes no audio session, and that AVKit's controls show only under `--touch platform`. The ios-driving recipe is not changed.
