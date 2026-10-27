# `state` prints the value that a password field is bound to

**Status:** Open
**Systems:** agent (`state`, a failed test's notes)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

`tree`, `layout` and the `type` reply show a `type="password"` field's value as `•••`
(`docs/contract-for-agents.md`, the paragraph on `input type="password"`). The state slot
that the field's `value` reads is printed in clear:

```
"type password not-a-real-secret"  ->  typed #22 "password" … value="•••"
"state password"                   ->  "not-a-real-secret"
```

A drive that signs in with a real password (typed from the Keychain) prints it with any
`state` read that includes the slot, into the agent's output. The docs say that what the
app stores is the app's own, so this is the documented behavior today.

Workaround in the app's AGENTS.md: "do not run `state` before the sign-in ends".

## What would help

`state`, `state --full` and a failed test's notes printing `•••` for a slot that a
`type="password"` field's `value` reads, as `tree` does for the field.

## Evidence

Seen on 2026-10-27 on the iOS simulator.
