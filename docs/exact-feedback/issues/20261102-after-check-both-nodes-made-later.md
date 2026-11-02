# After check both, nodes made later in the drive drew in the other color scheme

**Status:** Open
**Systems:** agent check, apple host
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

In one `agent ios` drive under `prefer prefers-color-scheme light`:

1. `check both` on a chat screen.
2. A tap that opens a file picker, a `pick` answer, then the tray of picked files shows.
3. The new tray drew in the dark scheme in a light app: white text on a light grey tile.
   The software keyboard was dark too.
4. `check` then reported contrast failures on those nodes, such as `1.3:1 (#ffffff on
   #dedee1)`.

A new drive with the same steps but no `check both` before them drew the tray right, and
`check` found nothing. Seen once; not isolated further.

Cost: about 8 minutes, and a color fix written first for a bug that was not there.

## What would help

- `check both` putting the drive's scheme back for everything made after it.
- Or its output saying which scheme the drive is in after it, so a later finding can be
  read in that light.

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0`, `agent ios` on an iOS 26.5 Simulator.
