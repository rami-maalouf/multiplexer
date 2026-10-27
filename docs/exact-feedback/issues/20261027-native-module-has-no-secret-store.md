# A native module cannot keep a secret in Exact's store, so its own Keychain items outlive a fresh drive

**Status:** Open
**Systems:** native modules (`ExactModuleContext`), `secret.keep` (LLP 1018), agent fresh storage (`EXACT_AGENT_STORAGE_FRESH`), docs
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

The session token is used in Swift (the library's client restores itself from it), so
the module keeps it in its own Keychain item, and the library's store in `context.data`.
`ExactModuleContext` has `data`, `cache` and `temporary`, but no secret store.

A fresh agent drive (`verify ios`) emptied `context.data` but not the module's Keychain
item, and did not tell the module. On the next drive, the module found a session whose
store was gone. A session without its crypto store cannot be used, so the module dropped
it. It could not sign out on the server, so a test device stayed on the account (seen in
the account's device list).

Exact's own secret store (`secret.keep`, then `store.get` and `store.set` in the data
module; `docs/recipes/files-and-grants.md`) clears with a fresh drive. But a native
module cannot reach it, and `docs/recipes/native-module.md` does not mention it, so it was
not found while writing the module.

## What would help

- A secret store on the module's context: get, set and forget a secret that
  `secret.keep` grants, in the same store as the data module's, so it follows `--storage`
  and a fresh drive. Later, an app extension (a notification service extension) needs to
  read it too.
- Or, smaller: a flag on `context` that says the drive started its store empty, so a
  module can clear what it keeps elsewhere.
- One line in `docs/recipes/native-module.md` that points to `secret.keep`.

## Evidence

Seen on 2026-10-27. At `cee509ac82`, `ExactModuleContext`
(`host/apple/modules/ExactNativeModule.swift`) has no secret API, and Exact's only
Keychain code is its own (`host/apple/Sources/ExactKit/Presence.swift`).
