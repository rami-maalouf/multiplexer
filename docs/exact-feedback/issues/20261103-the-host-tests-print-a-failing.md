# The host tests print a failing test's name but not its assertion

**Status:** Open
**Systems:** host tests, build.mjs
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

`bun host/apple/build.mjs --test --ios --only <Class>` ended with lines such as
`Test case 'PageEdgesIOSTests.testA…()' failed on 'Clone 1 of iPhone 17 Pro - xctest (…)' (4.492 seconds)`
and "xcodebuild failed (65)". The assertion that failed, and its message, were not in the output. I
read them from the result bundle with `xcrun xcresulttool get test-results tests --path <…xcresult>`.
The run writes two bundles (the bare pass and the hosted pass), and the first one I opened was the
other pass's, which had no failure in it.

Cost: about 10 minutes.

## What would help

- The failing assertion's file, line and message under each failed test case in the output.
- Or the path of the bundle that holds the failure, next to the failed test.

## Evidence

Seen on 2026-11-03 at exact2 `574720f370`, iOS 26.5 simulator.
