# A tinted glass circle needs `appearance="none"` plus `backgroundMaterial="glass"`

**Status:** Open
**Systems:** contract compiler, Apple host
**Severity:** P3
**Author:** Cursor Auto, from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-06

## What happens

A round glass control that also carries a light colour wash (a stop button that should
read as liquid glass with a faint red tint) cannot use `buttonStyle="glass"` together with
`background-color`: the compiler refuses it (`lower-button-style`) and says a custom face
needs `appearance="none"` without `buttonStyle`. The working form is
`appearance="none"`, `backgroundMaterial="glass"`, and `background-color` on a round
button. The glass button card does not say that pair is how a tinted glass circle is
authored.

Cost: about 2 minutes.

## What would help

A line on the glass button card: a tinted glass circle uses `appearance="none"` with
`backgroundMaterial="glass"` and `background-color`; `buttonStyle="glass"` keeps the
platform face and refuses a tint.

## Evidence

Seen on 2026-11-06 at exact2 `ae8946aca0` (the app's integration checkout), compiling a
chat app's voice-stop control.
