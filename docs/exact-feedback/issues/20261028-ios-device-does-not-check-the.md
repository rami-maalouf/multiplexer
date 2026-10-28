# `ios --device` does not check the iPhone Rust target before building

**Status:** Open
**Systems:** exact.mjs ios --device, setup --check, the app's pinned Rust toolchain
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-28

## What happens

An app made by `exact new` had been built only for the simulator. Its pinned toolchain
(`rust-toolchain.toml`, 1.97.0) had the `aarch64-apple-ios-sim` target, not
`aarch64-apple-ios`. `bun exact.mjs ios --device --phone <udid> --run` checked the signing
profile first, as documented, then started the Rust build and failed a minute in, once
for each crate: "error[E0463]: can't find crate for `core` … the `aarch64-apple-ios` target
may not be installed". `rustup` was not on PATH (it is in `~/.cargo/bin`), so rustc's
`rustup target add aarch64-apple-ios` needed the full path and `--toolchain 1.97.0`.

Cost: about 3 minutes.

## What would help

- `ios --device` (and `setup --check`) checking the pinned toolchain's iPhone target before
  building, as it checks the profile, and naming the command:
  `~/.cargo/bin/rustup target add aarch64-apple-ios --toolchain 1.97.0`.

## Evidence

Seen on 2026-10-27 at exact2 `cee509ac82`, with an iPhone 16 Pro over Wi-Fi.
