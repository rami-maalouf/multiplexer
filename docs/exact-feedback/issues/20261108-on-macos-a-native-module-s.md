# On macOS a native module's print is read as the drive's reply

**Status:** Open
**Systems:** agent, macOS host, native modules
**Severity:** P2
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-08

## What happens

On the macOS host, a drive (`agent macos`) talks to the app over the app's standard input and
output: `Agent.out` is `FileHandle.standardOutput` (`host/apple/Sources/ExactKit/Agent.swift`),
and `jsonLines` in `scripts/agent-wire.mjs` takes the next line on that stream as the reply to
the pending op. A native module's `print` writes to the same stream. When the module prints
while an op waits, the drive takes the log line as the reply and fails:

```
op 6/11 `clock data`: unreadable reply: <the module's log line>
```

On iOS the same module and the same `print` work: the Simulator carrier reads the console
separately.

Cost: about 15 minutes to find (the message names a reply, not a log line), then a change in
every module file: a `moduleLog` helper that writes to standard error instead of `print`.

## What would help

In the stdio carrier, keep replies off file descriptor 1: duplicate it for `Agent.out`
(`dup(1)`) and point descriptor 1 at standard error (`dup2(2, 1)`), so app and module output
become host lines, as on iOS. Or have `jsonLines` take only lines that parse as a reply, and
keep the others as host lines. The native-module recipe could also say that a module logs to
standard error.

## Evidence

Seen on 2026-11-08 at exact2 `86559f737a`, `agent macos` on a chat app whose module logs each
answer it gives.
