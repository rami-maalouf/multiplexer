# verify leaves the drives' kept session signed out

**Status:** Open
**Systems:** agent (iOS drive), verify
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-06

## What happens

Drives keep the app's store and its saved session from one drive to the next ("this drive kept
the store `default` from earlier drives"), so a drive after a sign-in opens signed in. A chat app
signed in to an account in one drive, then `verify ios` ran its authored tests (each starts
signed out). The next drive met the sign-in screen: the account the drives had kept was gone.

Nothing said so: `verify` printed its result, and the drive failed only when its first tap
found no target. The drive had to sign in again, and I had to check on the server that the
dropped session left no device signed in (it did not).

Cost: about 3 minutes, plus the server check.

## What would help

- `verify` running in a store of its own and leaving the drives' store as it was.
- Or `verify` saying that it reset the drives' store, so the next drive starts signed out.

## Evidence

Seen on 2026-11-06 at exact2 `dd9343b324`, iOS Simulator (iOS 26.5): a sign-in drive, then
`verify ios`, then a drive whose first step was a tap on a signed-in screen. Seen twice.

Additional evidence (2026-11-07, exact2 `91d7b12620`): `test ios` does the same as `verify`. On the Simulator that the drives use, a drive kept a signed-in session; after `test ios` (all tests passed, nothing said about the store) the next drive met the sign-in screen. Seen twice: an earlier task ran the tests after its last drive and the next task's first drive found the app signed out. Each time a new sign-in drive was needed: a new device on the server, and a password typed again and then scrubbed from the run log (finding 116). About 10 minutes over the two.
