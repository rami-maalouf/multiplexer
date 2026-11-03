# A press inside a `swiperight` node keeps the touch, and nothing says so

**Status:** Open
**Systems:** Apple host (gestures), contract vocab, contract compiler
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat's photo was a `button` (`press` opens it, `contextmenu` holds it). To answer it with a
swipe right, as a text bubble is answered, it was wrapped in a node with `swiperight`,
`touch-action="pan-y"` and the spring `transition`:

```contract
box swiperight=reply touch-action="pan-y" transition="translate -exact-spring(300, 30, 1)"
  button appearance="none" press=open contextmenu=hold
    image photo
```

On iOS a real drag across the photo (`tap <id> drag 90 0` under `--touch platform`) opened
the photo: the swipe never began. The reason is only in the host's source
(`AgentPanIOS.swift`): "a press below a node keeps its swipe and drag bindings from the touch
(rule 3)". `contract vocab swiperight` says only "`swiperight=act` calls `action act`", the
pitfalls page's `swiperight` entry is about `touch-action`, and the build gives no warning.

A voice row built the same way (a play button inside the swiped box) seemed to work, because a
drag that starts on its waveform is not on the button. So the rule shows only where the press
fills the swiped node.

The fix in the app: one node with all three (`button ... press=open contextmenu=hold
swiperight=reply`), and the photo, video poster, sticker and file bubble made into components
that only draw.

Cost: about 15 minutes and three drives.

## What would help

- `contract vocab swiperight` (and the pitfalls entry) saying that a `press` inside the swiped
  node keeps the touch, and to put `press` and `contextmenu` on the swiped node itself.
- A compiler warning for a `press` that fills a `swiperight` node.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5), with `agent ios --touch platform`.
