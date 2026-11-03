# caps counts one more line than wc -l

**Status:** Open
**Systems:** caps
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

`bun scripts/caps.mjs` said "host/apple/build.mjs is 1501 lines, over the cap of 1500" while
`wc -l` said 1500. caps counts the empty string after the file's last newline as a line, so a
file that `wc -l` counts at 1,500 lines is over the cap.

Cost: about 3 minutes, and one more line to cut than planned.

## What would help

- caps counting lines as `wc -l` does, or its message saying how it counts.

## Evidence

Seen on 2026-11-02 at exact2 `880d4f8652`.

## Pull request (2026-11-03)

https://github.com/ccheever/exact2/pull/1365 (fixes it): caps no longer counts the empty string after a final newline, with tests at 1,500 and 1,501 lines.
