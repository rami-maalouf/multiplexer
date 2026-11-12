# A drive cannot show a component in a given state for layout

**Status:** Open
**Systems:** agent, ios
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-07

## What happened

A chat's transcript has a row above its oldest message: a small spinner while older messages
load, then a "start of the chat" line. The two had different heights, so the messages moved
when one replaced the other. To measure each state with `layout <testId>`, the row must show
that state during the drive. In the app the spinner state lasts about 0.3 s, during a page
load, so a drive cannot stop on it.

A drive cannot set a component's props or an app state. The workaround: edit the contract so
the row's prop is a constant, run a drive with `layout`, put the line back, and repeat for the
other state. Four edits and four drives (before and after a fix).

Cost: about 8 minutes.

## What would help

- `layout` and `screenshot` of one component with given props on the device, as the gallery's
  `--props` does for a widget.
- Or a drive op that sets a state for the rest of the drive.

## Evidence

Seen on 2026-11-07 at exact2 `f53339adc8`, iOS Simulator. `layout` then gave 40 pt against 36 pt
before the fix and 36 pt for both after it.
