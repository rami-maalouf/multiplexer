# An action in a members file the component does not name is reported as missing

**Status:** Open
**Systems:** compiler, members
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A new file `remind-members.contract` (`members App` with its actions) was not yet named by a
`members "./remind-members.contract"` line in the component. A handler on the root,
`notificationclick=openReminder`, was refused: "the root component has no action `openReminder`".
The message did not say that a members file in the app's folder declares that action but is not
named, which was the cause; the component's other `members` lines showed it.

Cost: about 2 minutes.

## What would help

- The refusal naming the members file that declares the name and the line to add, as the compiler
  names a missing `use`.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`.
