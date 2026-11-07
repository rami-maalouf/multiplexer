# A held device request shows only on clock settle

**Status:** Open
**Systems:** agent (iOS drive), permissions
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-07

## What happened

A drive recorded a voice message. The recording stayed at "0:00" with Stop disabled, and the drive then failed with "voice-stop is disabled". The cause was a held `permission` ticket for the microphone (`getUserMedia`), plus a second one. The drive reported the tickets only on a `clock settle`. The `clock +2500 real` after the tap passed in silence, and the disabled-Stop failure did not mention the held tickets. `--permission microphone=granted` at launch fixed it.

Cost: about 15 minutes, two takes.

## What would help

- A held device request reported on any clock step (also `+N real`).
- An op that fails on a disabled control naming held tickets as a likely cause.

## Evidence

Seen on 2026-11-07 at exact2 `8e547ca606`, iOS Simulator, `--timing platform --touch platform`.
