# The host tests cannot run one test class

**Status:** Open
**Systems:** Apple host, tests
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

To check one change to `RasterImage.swift`, the only command is `bun host/apple/build.mjs --test`,
which builds and runs all 318 test classes. On this machine that took more than 10 minutes, so
a first run in the foreground was stopped at the tool's time limit. To run one class I found the
test bundle under `target/clients/<hash>/…/tests/out/Products/Debug/ExactKitTests.xctest` and
ran `xcrun xctest -XCTest ExactKitTests.RasterImageTests <bundle>` from `host/apple`.

Cost: about 15 minutes.

## What would help

- `--test --only <Class>` (or a filter), or a line in `docs/testing.md` with the `xctest`
  command and where the bundle is.

## Evidence

Seen on 2026-11-02 at exact2 `880d4f8652`, macOS host tests.
