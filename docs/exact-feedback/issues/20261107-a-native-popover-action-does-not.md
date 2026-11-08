# A native popover action does not expose its authored test id

**Status:** Open
**Systems:** ios host, accessibility, native testing
**Severity:** P3
**Author:** Codex GPT-6.1 Sol, from an app outside exact2
**Date:** 2026-11-07

## What happens

An authored popover has `role="menu"` and an action with a `testId`. In an external
native accessibility drive, the opening button is reachable by its authored id,
but the action is not: the selector returns `Selector did not match`. The native
tree exposes the action as a labelled cell instead. Selecting the visible label
works and opens the intended screen.

This is a native identifier coverage limitation, not evidence that Exact's own
model-based driver cannot select the action. No claim is made about all popovers.

## What would help

Preserve action identifiers in native accessibility where supported, or document
which menu actions need a visible-label selector in a native driver. Successful
model-based tests should not imply native identifier coverage.

## Evidence

Seen on 2026-11-07 at integration checkout `4251663c25`, iOS 26.5 Simulator,
while signing a test account out of a chat app. The opening button's id worked;
the menu action's id failed; its visible label worked. About two minutes spent
inspecting the native tree. Kept local; no report sent.
