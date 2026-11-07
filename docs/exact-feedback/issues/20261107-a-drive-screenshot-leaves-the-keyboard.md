# A drive screenshot leaves the keyboard out

**Status:** Open
**Systems:** agent (iOS drive), screenshot
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-07
**Related:** issues/20261022-agent-cannot-drag-to-dismiss-the-keyboard-or-film-real-time.md (exact2)

## What happened

A drive's `screenshot` shows a dark band where the keyboard is. So a keyboard bug (a list that jumps as the keyboard comes up, a keyboard that comes back after a send) cannot be judged from drive screenshots. Each keyboard check needed `xcrun simctl io <udid> recordVideo` around the drive, frames cut with ffmpeg, and a small script to tile the frames with their times (the local ffmpeg has no `drawtext`).

Cost: about 5 minutes the first time, and about 5 more for the frame sheet script in a later task.

## What would help

- A drive screenshot option that includes the keyboard, or a note in the agent help that it is left out.
- A drive op that writes a labelled frame sheet of a recorded stretch under real timing.

## Evidence

Seen on 2026-11-07 at exact2 `8e547ca606` and again at `91d7b12620`, iOS Simulator, `--timing platform --touch platform`.
