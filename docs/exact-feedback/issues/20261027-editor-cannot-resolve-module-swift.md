# The editor cannot resolve native module Swift, so every line shows an error

**Status:** Open
**Systems:** native modules, `exact new`, `exact.mjs update`
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-27

## What happens

In an editor that uses SourceKit-LSP, every file in `modules/apple/` shows errors such
as `Cannot find type 'ExactModule' in scope`, `Cannot find 'ExactNativeRefusal' in
scope` and `Method does not override any method from its superclass`. These files
compile into one module with `host/apple/modules/ExactNativeModule.swift` and the app's
other Swift, and nothing tells SourceKit that. So the editor gives no useful feedback,
and real errors show only at the next build: 31 s or more with a large module (see
`20261027-module-swift-recompiles-vendor-bindings.md`).

## What would help

`exact new` and `exact.mjs update` writing an editor configuration for `modules/apple/`:
a `buildServer.json` (Build Server Protocol) or a stub `Package.swift` that names the same
sources and Exact's module file.

## Evidence

Seen on 2026-10-27 with exact2 `65577096ed`. No `buildServer` or SourceKit setup is in
`scripts/` or `host/apple/` at `cee509ac82`.
