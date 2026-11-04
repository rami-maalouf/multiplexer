# Exact's own host tests fail on origin main on an iOS 26.5 simulator and a Canadian English Mac

**Status:** Open
**Systems:** host tests
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

On this machine, with no change to exact2, these host tests fail on `origin/main` (`574720f370`):

- iOS 26.5 simulator: five or six of `NavigationCollapseIOSTests` (`testAnAgentDragPastTheTopOpensACollapsedLargeTitle`,
  `testAnAgentDragToTheEndUnderALargeTitleRestsAtTheEnd`, `testAnAuthoredScrollTopLandsAsTheBrowsersWhileTheTitleCollapses`,
  `testAScrollerReplacedInPlaceOpensAtItsTopBelowTheBarAsItWasLeft`, `testTheWheelUnderALargeTitleRestsAsAPersonsScrollDoes`,
  and in one of two runs `testASingleStacksFirstScreenOpensWithItsLargeTitleExpanded`), and
  `PushedTitleIOSTests.testATabSwitchAContentSwapAndAReplaceKeepIt` (two runs of two). Several of these
  tests say they were measured on iOS 27.
- macOS, region `en_CA`: `AccessibilityClientMacTests.testAnAlertDialogLandsVoiceOverOnTheButtonItsCommitFocused`
  expects `AXRoleDescription` "dialog"; AppKit says "dialogue".

To tell them from a change's own failures, each run needed a second run on `origin/main`.

Cost: about 20 minutes.

## What would help

- The iOS tests skipping, with a reason, on a runtime they were not measured on, or passing on iOS 26.5.
- The Mac test comparing the role description in a way that does not depend on the region (or
  running under `en_US`).

## Evidence

Seen on 2026-11-03 at exact2 `574720f370`: iOS 26.5 simulator (iPhone 17 Pro), macOS with `AppleLocale` `en_CA`.
