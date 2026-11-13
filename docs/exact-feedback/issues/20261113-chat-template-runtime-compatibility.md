# The chat template needs features absent from current main

**Status:** Open
**Systems:** Templates and documentation
**Severity:** P3
**Author:** Codex, from an external app feedback log
**Date:** 2026-11-13

The unchanged public chat template at `041917c8e1c9c2c076232a8011f0d5f40601ca01`
builds on its pinned framework `ad181418b37d5452a0c0e35f15bf6d3f45f4a212`.
Generating the same template against upstream `bdac0a1be3` (base `c419ce55c9`)
warns that the checkout does not contain the pin, then baking fails:

- `column` has no `swipe` or `swipe-direction` attribute.
- `--exact-layout-margins-inset-left/right` are unknown.
- `calc(100cqw - 32px)` is refused.

About three minutes were spent on the unsuccessful build. Both apps were generated
through the supported `new.mjs chat` command with an explicit framework checkout;
no template source was changed. The comparison continued on the supported pin.
Its 14 native iOS tests and 13 data tests passed.

The pin's Apple host also lacks `TimerScrollTouch`, present on current main.
Similar list markup therefore cannot establish a same-runtime control for a
gesture-observer regression. Checking the actual pinned source was necessary.

A compatibility note naming the branch-only features, and a supported current-main
template revision when available, would make this limitation clear before building.
The existing non-ancestor warning is useful but does not identify the missing features.
