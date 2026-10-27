# The native-module recipe leaves out the module's folders, its Swift mode, and how `clock data` treats `later`

**Status:** Open
**Systems:** docs (`docs/recipes/native-module.md`)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

A module with a slow `later` (a network sign-in of several seconds) needed three facts
that the recipe does not give. Each came from `host/apple/modules/ExactNativeModule.swift`
(77 KB), `host/apple/build.mjs` or a search of the long guides: about 15 minutes in all.

1. `context.data`, `context.cache` and `context.temporary` are the app's own folders,
   and a scratch tree under the agent.
2. Modules compile with `-swift-version 5`, so a `Task { @MainActor in … }` inside
   `later` compiles without Swift 6's strict checks.
3. `clock data` waits for a `native.later` reply in flight. It did, for replies of
   several seconds.

The recipe also does not mention `secret.keep`
(`20261027-native-module-has-no-secret-store.md`) or Exact packages
(`20261027-module-swift-recompiles-vendor-bindings.md`).

## What would help

Three lines in the recipe, and pointers to the two other topics.

## Evidence

The recipe is unchanged between `65577096ed` and `cee509ac82`.
