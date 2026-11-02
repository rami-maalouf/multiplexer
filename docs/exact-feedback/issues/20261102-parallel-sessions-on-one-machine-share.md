# Parallel sessions on one machine share the default Simulator, and an install replaces another session's app mid-drive

**Status:** Open
**Systems:** agent, ios builds
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

Several agent sessions built the same app at once, each in its own git worktree of the app's
repository. `exact.mjs ios --run`, `test ios`, `verify ios` and `agent ios` with no `--sim` all
use the same default Simulator, and every worktree's app has the same bundle id. So:

1. My `ios --run` installed my build over the app another session was driving at that moment
   (its process list showed `agent ios ... --sim <the default Simulator's udid>`).
2. That Simulator's app was signed in to another session's account (the agent keeps its
   session per Simulator), so my first drive started in the wrong account.
3. `agent ios --sim "<another named Simulator>"` was refused: "another drive of this store is
   open on simulator ... (stream is locked by another publisher)". The message was clear; that
   Simulator was in use by a third session.

What worked: a Simulator of my own (`xcrun simctl create`), and `EXACT_SIM=<its udid>` for every
build, test, verify and drive.

Cost: about 15 minutes, and possibly a broken drive in another session.

## What would help

- A default Simulator per app folder (or per worktree), made on first use, so parallel work
  does not collide.
- `ios --run` (and `test`, `verify`) warning, or refusing, when an agent drive of the same app
  is open on the Simulator it is about to install on.

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0`: four worktrees of one app, each with its own agent
session, on one Mac.
