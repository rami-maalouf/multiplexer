# A drive cannot cross the app leaving the foreground and coming back

**Status:** Open
**Systems:** agent driver, Apple host
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-06

## What happens

A reader found a list frozen after returning to the app. To reproduce it, a drive must scroll,
send the app to the background (Home, the app switcher, lock), bring it back, and scroll again,
all in one running app. The agent drive has no op for Home, the app switcher or lock, and when
another tool sent the app to the Home Screen mid-drive, the op in flight failed: "the app left the
foreground (a share extension or another app took the screen), so it is suspended and every op
fails until it is back"; the drive ended, though the app was back 6 s later. Each drive is a new
launch, so a return to a running app cannot be driven at all.

exact2's `bench/bakeoff/drive.mjs` (the same touch runner, on the running app by bundle id, with
`home`) did it; it needs its `launch` op first, or the app's accessibility tree is off
(`kAXErrorAPIDisabled`).

Cost: about 30 minutes.

## What would help

- Drive ops for Home, the app switcher and lock (the touch runner has `springboard` home and lock).
- An op that waits for the app to come back, instead of failing every op while it is away.

## Evidence

Seen on 2026-11-05 at exact2 `919ae4220a` (the app's integration checkout), iOS Simulator (iOS 26.5).

## More evidence (2026-11-06, a second lane)

Proving that a chat keeps its messages over a return needed exact2's `bench/bakeoff/drive.mjs`
(real touches, `home`) and `xcrun simctl launch` to come back, plus `simctl io recordVideo` to
see the return: Exact's own drive could not. The recording showed a real bug (the chat stepped
back to an older list several times a second for 6 s) that no Exact drive could have caught.
About 20 minutes to set up.
