# `contract vocab` does not know an input's `type` values

**Status:** Open
**Systems:** contract vocab
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat app needed a date and time picker for "send this message at ...".
`contract vocab datetime-local` answered: "not a built-in tag or attribute, so a built-in tag
refuses an attribute of that name; a hyphenated tag (`map-view`) is a native module". That
reads as "Exact has no such thing". `contract vocab input` named no `type` values. The picker
exists: `input type="datetime-local"` is a compact `UIDatePicker` on iOS, its value without a
zone. I found it by grepping the iOS host's source (`DatesIOS.swift`), then in
`docs/contract-for-agents.md`.

Cost: about 4 minutes.

## What would help

- `contract vocab` answering an input `type` value (`date`, `time`, `datetime-local`, `file`,
  `search`, ...) with what it is on each host, and that a date's value carries no zone.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5).
