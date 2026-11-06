# Which swipe action a full swipe performs is not documented

**Status:** Open
**Systems:** contract docs, Apple host (swipe actions)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-05

## What happens

A chat app's list rows got two trailing swipe actions (Archive and Mute), where a full swipe
must archive. `contract vocab swipe` and `docs/contract-for-agents.md` say a full swipe
"past half the row" presses "the outermost action", but not which id of `swipeTrailing`
(or `swipeLeading`) is the outermost. The answer is in the iOS host:
`host/apple/Sources/ExactKit/IOS/SwipeActionsIOS.swift` builds UIKit's actions in the listed
order and sets `performsFirstActionWithFullSwipe = controls.first`, so the first id listed is
the outermost action and the full-swipe one (`swipeTrailing="archive mute"`).

Cost: about 5 minutes reading the host.

## What would help

- One line in the swipe vocab entry: "the first id is the outermost action, which a full swipe
  performs".

## Evidence

Seen on 2026-11-05 at exact2 `d0d66b107e` (the app's integration checkout), iOS Simulator (iOS 26.5).
