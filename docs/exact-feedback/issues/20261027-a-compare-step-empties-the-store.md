# A `compare` step empties the store for the whole drive, without saying so

**Status:** Open
**Systems:** agent (screenshot compare, drive storage)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

A drive signed in at its start and ended with
`"screenshot after.png compare before.png"`. It failed at its second step, a `tap` on a
row of the signed-in screen: "no view matches … targets here: sign-in, server, user,
password". The app was signed out, because a drive that compares starts its store empty.
`docs/recipes/ios-driving.md` says so in one sentence.

So a step at the end of a drive changed how the drive began, and the refusal did not say
why the screen was not the one the earlier drives had left. A native module of the app
also saw its data reset (and cleaned up after it, which hid the cause further).

Cost: about 5 minutes.

## What would help

- The drive saying at its start: "store started empty: this drive compares".
- Or `compare` keeping the store when the drive passes `--keep-storage`.

## Evidence

Seen on 2026-10-27 at exact2 `cee509ac82`, on iOS: the agent's `default` storage folder
was recreated at the drive's start.
