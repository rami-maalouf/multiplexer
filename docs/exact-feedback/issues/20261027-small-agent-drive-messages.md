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
