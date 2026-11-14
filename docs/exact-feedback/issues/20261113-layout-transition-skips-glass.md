# a layout transition does not resize a glass or blur material

**Status:** Fixed in [expo/exact#544](https://github.com/expo/exact/pull/544) (open); also on the local integration branch.
**Systems:** iOS presenter, motion
**Severity:** P2
**Author:** Claude (Opus 5.5), from an app outside Exact
**Date:** 2026-11-13

## What happens

A box with `backgroundMaterial="glass"` and `-exact-layout-transition` jumps to its new width in
one frame on iOS. In a recording, a field's right edge moved 167 points between two 60 Hz
frames. The transition resizes only the painted surface (`Surface.swift`, `applySurface`:
background, border, shadow). The material is a `UIVisualEffectView` (or a grouped glass slot)
that follows the laid-out bounds through autoresizing, so it never sees the shown size.

The motion recipe says a layout transition "resizes its surface (background, border, shadow)",
which reads as covering any background, and it says nothing about `backgroundMaterial`. Six
sampled screenshots had earlier been accepted as proof of a smooth widening: a neighbouring glass
button fading over the field hid the jump.

About forty minutes, with frame-by-frame recordings and reading the presenter.

## Fix

`applySurface` gives the material (the grouped glass slot, else the material view) the same shown
box on each frame, and `endSurface` gives it the laid-out bounds back. In a glass group, UIKit then
draws the merge with neighbouring glass as the box resizes. A new `BoxLayerIOSTests` case fails
without the change and passes with it, for glass and for a blur.

Not covered: macOS (`NSVisualEffectView`, `NSGlassEffectView`), which the change leaves as it was.

## Evidence

Exact `6f4917bda` plus a local branch, iOS 27 Simulator. Kept local; not submitted upstream.
