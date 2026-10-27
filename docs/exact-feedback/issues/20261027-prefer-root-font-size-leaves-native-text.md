# `prefer root-font-size` enlarges Exact's text but not native fields or list footers

**Status:** Open
**Systems:** agent (`prefer`), Apple host (iOS), Dynamic Type
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

To see a sign-in form at the largest text size, a drive ran `prefer root-font-size 53`.
The labels grew. The native fields' text and placeholders, and the grouped list's footer,
kept the default size. So the screenshot showed a screen that no device shows, and it
looked broken. The simulator's own setting (`xcrun simctl ui <udid> content_size
accessibility-extra-extra-extra-large`) showed the real screen, which was correct. Cost:
about 3 minutes.

## What would help

A `prefer` key that sets the content size category, so UIKit's text follows too; or the
docs saying that `root-font-size` reaches only the text that Exact draws.

## Evidence

Seen at exact2 `65577096ed` on the iOS simulator.
