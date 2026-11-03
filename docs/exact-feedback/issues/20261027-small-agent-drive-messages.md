# Eight agent messages that could say what to do next

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

## Three more (2026-11-02, `ed43ad09a0`)

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
8. A held file picker answered with one quoted path that has a space,
   `"type @pick-files '/tmp/x/Trip plan.pdf'"`, failed with `type @pick-files: no such file
   /tmp/x/Trip`: `type @` splits its text on any whitespace when it has no newline
   (`pickedPaths`, `scripts/agent-keys.mjs:369`). `agent-pitfalls.md` names the step that keeps
   the path whole (`pick pick-files "<path>"`), but the message does not, and the line on held
   requests in `contract-for-agents.md` (around 3756) shows only `type @pick photo.jpg`. The
   message could say "a path with a space: `pick <id> \"<path>\"`". About 3 minutes and a drive.

## Seen again, and one more (2026-11-03, `ed43ad09a0`)

- Item 7 again: in a chat that marks itself read one second after it shows (which refreshes
  its list), `screenshot <png> window` gave `pixels="app"` in most tries. A `clock 4000` before
  the screenshot gave the display in some drives, not all. About 10 minutes.
9. `pick pick-photos <path>` before the picker was open answered "no held device request
   answers at that node or has that capability (held: none)". True, but it could name the next
   step: "open the picker first (the press that calls `showPicker`), then `pick`". About 2 minutes.

## Pull request (2026-11-02)

https://github.com/ccheever/exact2/pull/1338 (fixes part of it): five of the eight messages name the step to write (reload, `--scale` in a step, `prefer dark`, `state --json` in a step, a picked path with a space). The other three are design questions.

## Seen again, and one more (2026-11-03, message menu task, `ed43ad09a0`)

- Item 7 again, over an app-drawn long-press overlay and in sheets: `screenshot <png> window`
  gave `pixels="app"` in almost every try ("the display changed while it was read", or "the app
  named no points to check the display against"), also with `--timing platform`, `clock +3000`
  and `clock settle` before it. Under `--timing platform`, `clock +15000` did not keep the app
  up in real time: a display capture taken from a second shell during that step showed the home
  screen. What worked: `clock until state <path> == "never" within 12000` (which waits in real
  time, then fails the drive) and `xcrun simctl io <udid> screenshot` meanwhile. A `hold <ms>`
  step, or a window screenshot that waits for a still display, would remove it. About 25
  minutes over the task.
10. `clock 600` after a `clock +2500` answered "the clock cannot go backwards (2500.0 → 600.0)".
   Clear, but it could add that `clock +600` advances by 600. About 1 minute.

## Two more (2026-11-03, one chat's search task, `ed43ad09a0`)

11. `key Enter` (to press the keyboard's Search key) answered "unknown op: key". The help reads
   `type <target> <text>|key <Name>`, so `key` is a form of `type`, but the refusal lists only
   the ops. It could say "`key` goes after `type <target>`: `type search-field key Enter`".
   About 1 minute.
12. `clock until state jumpedTo != "" within 20000` answered with the grammar, `== <literal>`
   only. To wait for a state to take any value, a drive needs a fixed `clock +N` and a `state`
   after it. `!=` (or "until it changes") would remove the guess. About 1 minute.

## One more (2026-11-03, a jump count task, `ed43ad09a0`)

13. A chat row that new messages had moved down a virtualized list: `tap room-<id>` answered "its
   middle is outside the viewport; scroll it into view first", and `tap room-list into
   room-<id>` answered the same. The refusal could show the `tap <list> into <key>` form with the
   list's own key for that row (its `key`, not its `testId`). About 3 minutes.

