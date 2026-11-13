# Smooth scrolling cannot be limited to following a list's end

**Status:** original observation preserved; resolved for virtualized lists on the validated 2026-11-13 integration
**Systems:** contract, list, scroll
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-07

## What happened

A messaging app animates the follow of the end when a row is appended. `scroll-behavior="smooth"` on a followed list would do that, but it also animates every other programmatic scroll of that list (an open at the first unread, a jump to a found message). So the append stays a one-frame shift of one row.

Cost: not timed (a short try, then left as it is).

## What would help

A way to animate only the follow of the end (a list attribute, or an option on the follow).

## Evidence

Seen on 2026-11-07 at exact2 `4a187c1bbe`, iOS Simulator, a chat transcript.

## Recheck on 2026-11-13

On Exact `6f4917bdab8b5392a78c2e4e6b6d8d3b28e9317c`, a virtualized list can animate end-follow independently. `scroll-behavior="smooth"` selects smooth anchor corrections in `runner/src/instance/collection/mod.rs`; `runner/src/runner/into_view.rs` selects a keyed reveal's animation only when its explicit behavior is smooth. The default keyed reveals used for unread and search placement remain immediate.

A chat send still jumped because the list omitted the style while a later send callback requested smooth scrolling. Enabling the style, with `auto` for reduced motion, changed an observed one-step shift into gradual motion in a standalone iOS recording. No framework change was needed.

The remaining documentation gap is the distinction between automatic following and an explicit reveal. Confirming it required the template and runner source, about 10 minutes. The chat-thread recipe should show the list style alongside the explicit send reveal.
