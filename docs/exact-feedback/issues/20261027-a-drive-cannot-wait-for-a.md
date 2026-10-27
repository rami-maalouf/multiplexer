# A drive cannot wait for a native module's own background work

**Status:** Open
**Systems:** native modules (ExactModuleContext), agent clock (clock data)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

At launch, a native module's `call` (on the main thread, inside the 100 ms budget) finds
work that needs the network: here, a stale session to sign out on the server. It starts a
`Task` and answers at once. No data-module request waits on that task.

A drive that must check the result has no condition to wait on. `clock data` waits for
the data module's requests in flight, and this work is not one of them; `clock settle`
waits for transitions. The only way was a fixed real-time wait, `"clock +4000 real"`,
then `logs` to read the module's `print`. `docs/card.md` says never to wait in real time.
Cost: about 3 minutes, and a drive that is slow and can still be flaky.

## What would help

- A way for a module to say it is busy, which `clock data` waits for and whose reply
  names it, as it names a held request: for example `context.busy("sign-out") { … }`, or a
  ticket from `context.begin("sign-out")` that the module ends.
- Or one line in `docs/recipes/native-module.md` saying how a drive should wait for work
  a module starts by itself.

## Evidence

Seen on 2026-10-27 at `cee509ac82`. `ExactModuleContext`
(`host/apple/modules/ExactNativeModule.swift`) has `changed`, `wrote`, `now`, `after` and
`frames`, but nothing that tells the agent's clock that the module has work in flight.

## More evidence: a change the module pushes after a mutation

A drive tapped Delete on a failed message. The mutation's reply came at once; the row went
away later, when the module called `context.changed` and the resource was asked again.
`clock data` lands the reply, not the later push, and `clock until state <path> ==
<literal>` has only `==`, so "until this row is gone" cannot be written. The drive used
`"clock +2000 real"`. What would also help: `clock until state <path> != <literal>`, or
`clock until tree missing <testId> within <ms>`. Seen on 2026-10-27 at `cee509ac82`.
