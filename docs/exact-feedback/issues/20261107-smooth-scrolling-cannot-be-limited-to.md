# Smooth scrolling cannot be limited to following a list's end

**Status:** Open
**Systems:** contract, list, scroll
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-07

## What happened

A messaging app animates the follow of the end when a row is appended. `scroll-behavior="smooth"` on a followed list would do that, but it also animates every other programmatic scroll of that list (an open at the first unread, a jump to a found message). So the append stays a one-frame shift of one row.

Cost: not timed (a short try, then left as it is).

## What would help

A way to animate only the follow of the end (a list attribute, or an option on the follow).

## Evidence

Seen on 2026-11-07 at exact2 `4a187c1bbe`, iOS Simulator, a chat transcript.
