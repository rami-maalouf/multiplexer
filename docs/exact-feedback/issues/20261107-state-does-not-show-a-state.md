# state does not show a state declared in a members file

**Status:** Open
**Systems:** agent (iOS drive), state
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-07

## What happened

A drive needed to know whether a voice recording had started. The value is a `state` that a `members` file declares for the root component. `state` did not show it, so whether recording had started could be seen only on a screenshot or a video.

Cost: about 3 minutes.

## What would help

`state` listing every state of the component, also those that a `members` file declares.

## Evidence

Seen on 2026-11-07 at exact2 `8e547ca606`, iOS Simulator. Recorded in the task diary; not checked again since.
