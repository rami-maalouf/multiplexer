# audio-waveform's tint takes only a hex colour

**Status:** Open
**Systems:** @exact/recording, Apple
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

`@exact/recording`'s `audio-waveform` view draws a microphone's live level. Its `tint` prop is
`option<string>`; on Apple, `Waveform.setProps` reads it with `Waveform.color(hex)`, which
parses a hex literal only. A colour role (`-exact-system-red`) or a tamber token is not a hex,
so the view keeps its default colour, with no warning. A recording bar that is red in the
system's red has to write `tint="#ff3b30"`: the light scheme's red, also in dark mode, where
the system's red is `#ff453a`, and `no-tells` lists the literal.

Cost: about 3 minutes (reading the package's Swift to learn which values work).

## What would help

`tint` taking what `color` takes (a role, a tamber token, `light-dark()`), or the compiler
refusing a value the view cannot read.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0` (`packages/recording/apple/Recording.swift`,
`Waveform.setProps` and `Waveform.color`).
