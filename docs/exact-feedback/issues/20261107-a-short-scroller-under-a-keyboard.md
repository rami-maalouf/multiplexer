# A short scroller under a keyboard toolbar rises by the whole keyboard

**Status:** Open
**Systems:** host/apple, ios scroll, keyboard
**Severity:** P2
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-07

## What happened

A chat screen uses `interactive-widget="overlays-content"` with the composer as the keyboard toolbar. When the transcript was shorter than its port, the keyboard coming up moved every row up by the whole keyboard (317 points): the newest rows went behind the top bar. The next appended row moved them back, so a send looked like a jump.

The cause was in the iOS host. The keyboard toolbar gives the scroller under it a bottom content inset, and the host keeps a scroller's content size at least its box (`scrollFloor`). A short transcript then counted as "at its end" at the full keyboard's height.

Cost: about 40 minutes from the first recording to the cause.

## What would help

- The floor leaves the keyboard's inset out, set before the inset changes, so UIKit's own inset callback keeps the content's own end. Done locally in exact2 `4a187c1bbe`.
- A host test with a short scroller under a keyboard toolbar. The existing ones all used content taller than the port.

## Evidence

Seen on 2026-11-07 at exact2 `8e547ca606`, iOS Simulator, real touches (`--timing platform --touch platform`) recorded with `simctl io recordVideo`. Fixed and seen again at `4a187c1bbe`.
