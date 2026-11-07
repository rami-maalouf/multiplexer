# a saved native test run can no longer name its test bundles

**Status:** Open
**Systems:** native test runner
**Severity:** P3
**Date:** 2026-11-07

## What happened

Replaying the saved `exact-tests.xctestrun` with `xcodebuild test-without-building` failed with `there are no test bundles available to test`. The runner had rewritten the same file while splitting the preceding run into test groups. Rebuilding through `build.mjs --test --ios --only <class>` was necessary instead of replaying the successful group's existing binary.

Cost: about two minutes identifying the replay problem, plus rebuilding.

## What would help

Keep a distinct xctestrun or replay command for each test group, including its environment, so a completed test run is repeatable without rebuilding.

## Evidence

Seen at framework commit `ec081ea28a`, iOS Simulator. The original focused menu test run completed successfully; replay from its final saved xctestrun returned the error above.
