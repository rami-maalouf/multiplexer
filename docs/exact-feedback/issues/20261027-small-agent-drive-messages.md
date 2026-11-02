# Four agent messages that could say what to do next

**Status:** Open
**Systems:** agent (`scripts/agent.mjs`, `scripts/agent-test.mjs`), `verify`
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

Each cost 1 or 2 minutes.

1. `reload` in an `agent ios` drive: "reload in an interactive drive supports web; native
   authored tests relaunch their host". Each drive is a new launch, so a second drive
   proves a relaunch. The message could say so.
2. `"screenshot .exact/x.png --scale 3"`: "screenshot: unknown form 3". `--scale` is a
   drive flag. The message could name it.
3. `agent ios "prefer dark"`: the reply listed every accepted key. The step is
   `prefer prefers-color-scheme dark`. A suggestion of the nearest key would save the
   search. (Seen at `65577096ed`.)
4. `verify ios` reported 13 findings (covered, contrast, overlap at the largest text size)
   on a test that ended with an alert open. That follows the rule (a test's end is a
   screen it checks), but no finding said that an alert was up. The fix was to close the
   alert at the end of the test.

## Evidence

The messages in items 1 and 2 are unchanged at `cee509ac82`.

## One more (2026-11-02, `1bc4c36cb7`)

5. `state thread` refused to print 8.2 KB and said `all of it: "state thread --full", or
   --json`. As a drive step, `"state thread --json"` printed the same short summary again,
   with no word that `--json` was not taken there. `"state thread.messages.19"` worked. About
   3 minutes and three drives.

## Two more (2026-11-02, `ed43ad09a0`)

6. A bar was a `row position="absolute"` with `pointer-events="none"` (only its buttons take
   touches), and its pull-down menu (a `popover` column) was inside it. In a drive the
   painted menu's rows could not be tapped: "tap #116 at (75.83, 663.83): node #90 covers
   its middle", node #90 being a list row under the menu. The cause was the popover
   inheriting `pointer-events: none` from the row, as CSS does; `pointer-events="auto"` on
   the popover fixed it. The refusal could name the inherited `pointer-events: none` on the
   target. About 4 minutes.
7. `screenshot <png> window` answered "the picture is the app's own drawing ... (the app
   changed while the display was read)" in every try during one session, so the glass in it
   was approximate. I took the display with the simulator's own screenshot command during a
   long `clock +12000 real` instead. The step could wait for a quiet moment, or say what kept
   changing. About 8 minutes.
