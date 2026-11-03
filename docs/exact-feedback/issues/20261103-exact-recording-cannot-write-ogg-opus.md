# @exact/recording cannot write Ogg Opus, the voice note format of chat networks

**Status:** Open
**Systems:** @exact/recording
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat app sends a recorded voice message to a chat network through a bridge. The bridge
passes the file on as it is (no conversion) with a voice-note mark, and the network's own voice
notes are Ogg Opus, so the app sends Ogg Opus to be sure the network plays it as one of its
own. `@exact/recording` on Apple
writes `audio/mp4` (AAC, ALAC, or Opus in MP4 with `apple.formatID`) or `audio/wav`;
`isTypeSupported("audio/ogg")` is false. So the app's native module converts each recording:
it reads the file with `AVAssetReader` (48 kHz mono floats), encodes it with AudioToolbox's Opus
encoder (`AVAudioConverter`), and writes the Ogg pages itself (the Opus head and tags, the
lacing, the granule positions and Ogg's CRC): about 200 lines, with a waveform measured in the
same pass for the message's metadata.

Cost: about 45 minutes, including checking the result with ffprobe and on the simulator.

## What would help

`audio/ogg` (Opus) as a recorder type on Apple, as browsers' MediaRecorder offers Opus in WebM
or Ogg; and a recorded file's waveform (its levels over the whole take, not the live level), so
a sender does not measure it again. Both are design questions for the Exact team.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0` (`packages/recording/apple/Recording.swift`:
`Recorder.path` knows `.m4a` and `.wav`; `isTypeSupported` answers `audio/mp4` and `audio/wav`).
