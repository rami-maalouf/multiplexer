# Content placed inside a glass group row takes its glass away

**Status:** Open
**Systems:** glass, docs
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-04

## What happens

A floating bottom bar is a `row … glassGroup=12` holding round glass buttons (`buttonStyle="glass"`)
and a glass capsule. To give the rows under it an edge effect, two absolutely placed views went in
as the row's first children: a solid `-exact-background` box behind the bar and a gradient above it.
In a screenshot the two round glass buttons then showed no glass at all (no edge, no shadow: flat on
the page), while the capsule, which has its own fill, still showed. Moving the two views out of the
row, into a wrapper around it, brought the buttons' glass back. Why the group did this is a guess
(the group may take the new views into its glass container); `contract vocab glassGroup` and the
glass docs do not say what a glass group does with a child that is not glass.

Cost: about 5 minutes, and one more build.

## What would help

- A line in the glass docs: what a `glassGroup` does to children that are not glass, and that a
  backdrop belongs outside the group.

## Evidence

Seen on 2026-11-04 at exact2 `ed43ad09a0`, iOS 26.5 simulator, light and dark.
