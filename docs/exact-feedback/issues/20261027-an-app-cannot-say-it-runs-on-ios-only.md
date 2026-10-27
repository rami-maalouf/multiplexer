# An app whose data comes from an iOS module cannot say that it runs on iOS only

**Status:** Open
**Systems:** `exact.mjs update --without`, authored tests, `verify`
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

All of the app's data comes from its Swift module, so the web build can only show the
first screen. `bun exact.mjs test` on the web fails 2 of 3 tests, which pass on iOS
(`text of "problem" is "<the web fallback's refusal>", expected "<the server's
reason>"`). `update --without` takes `linux` and `android`, not `web`, and a test has no
host line, so `test` and `verify` cannot be told to skip the web.

Workaround in the app's AGENTS.md: "run `test ios` and `verify ios` only".

## What would help

`update --without web` for an app that ships no web build, or a host launch line
(`host ios`) on a test or a test file.

## Evidence

Seen on 2026-10-27 (`bun exact.mjs test`: 1 passed, 2 failed).
