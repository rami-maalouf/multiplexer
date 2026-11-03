# The host tests check for the Metal toolchain only after the Rust build

**Status:** Open
**Systems:** host tests, build.mjs
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

`bun host/apple/build.mjs --test --ios …` on a Mac without Xcode's Metal toolchain built the Rust
targets first (about 45 seconds), then stopped: "this build compiles the SVG filter kernels with
Xcode's Metal toolchain, which is not installed. Install it with `xcodebuild -downloadComponent
MetalToolchain`". The message is clear; it came only after the build.

Cost: about 2 minutes, then the download.

## What would help

- The check before the Rust build, as `ios --device` checks its Rust target first.

## Evidence

Seen on 2026-11-03 at exact2 `574720f370`.
