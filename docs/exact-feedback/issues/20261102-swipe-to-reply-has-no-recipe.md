# Swipe to reply has no recipe: the transition's role, swipeIndicator and the threshold haptic are undocumented

**Status:** Open
**Systems:** docs (chat-thread recipe, agent-pitfalls), swiperight, Apple host
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

A chat app has swipe to reply on its bubbles: `swiperight=startReply(...)` and
`touch-action="pan-y"`, as agent-pitfalls says. Three parts of that gesture are not in any
guide, and one line about them is wrong:

1. **The `transition`.** The chat-thread recipe says nothing about swiping. The only line on
   the bubble's `transition="translate -exact-spring(300, 30, 1)"` (the sample chat app's) is
   in agent-pitfalls, under "A `swiperight` hears nothing from a finger on iOS": "which moves
   it with the finger". An earlier session read the recipe, left the transition out, and
   concluded that "the platform's swipe fires once and the bubble cannot follow the finger".
   Measured on the iOS Simulator with `agent ios --touch platform` (`tap <bubble> drag 110 0
   over 400 hold 600 during "screenshot ... window"`, then `screenshot ... over 600 every 50
   window` after the lift): without the transition the bubble already follows the finger, and
   it is back in place in the first frame after the lift (a snap). With the transition it
   springs back over about 250 ms. So the transition gives the return, not the follow.
2. **`swipeIndicator`.** It has no doc, no `contract vocab` answer and no use in a sample
   app; it is in `kernel/tables/schema.json` and `host/apple/.../GestureHold.swift`. Reading the
   Swift: the swiped node's first direct child with `swipeIndicator=true` gets holds on its
   opacity and scale, driven from their authored values to 1 as the swipe reaches its
   threshold. A reply arrow with `opacity=0 scale=0.4` and spring transitions on both worked
   at once: faint at 40 points of drag, full at 100. It moves with the bubble, because it is
   the bubble's child.
3. **The threshold haptic.** The Apple host fires a selection haptic when a swipe crosses its
   threshold, and again if it falls back under it (`NodeViewIOS.swift`, `swipeArmed`).
   Nothing says so, so the app also called `haptic("selection")` in the action the swipe
   fires, and the person felt two.

Cost: a wrong conclusion in one session; about 40 minutes in the next to measure the
motion, read the host's source and find the second haptic.

## What would help

- A swipe-to-reply section in the chat-thread recipe: `swiperight`, `touch-action="pan-y"`,
  the `transition` (and that it gives the spring back), a `swipeIndicator` child for the
  arrow, and the haptic the host already gives.
- The agent-pitfalls line corrected: the hold moves the node with or without the transition.
- `contract vocab swipeIndicator` answering, and `swiperight`'s entry naming the haptic.

## Evidence

Seen on 2026-11-02 at exact2 `1bc4c36cb7` (iOS Simulator, iOS 27.0). Related: finding 26 (a
drive cannot say "swipe right"), `issues/20261022-no-swipeleft.md`.

## A fix (2026-11-02)

Pull request https://github.com/ccheever/exact2/pull/1323: a "Swipe to reply" subsection in
`docs/contract-for-agents.md` (the follow, the 64-point threshold, `touch-action`, the
transition, `swipeIndicator`, the haptic, a test's drag), and the agent-pitfalls line
corrected. The recipe itself has no room for it: recipes have a 3,072-byte cap.

## More (2026-11-02)

Building the arrow in the app found three more gaps, now in the same pull request: `symbol:reply`
is a speech bubble (SF Symbols' `bubble.left`), and the left-turning reply arrow has no named
symbol, so the app declares it as an icon token; the swiped node needs `position="relative"`
so the indicator is placed against it; and the indicator's own `transition` sets how it leaves
after the lift (with the node's spring it trailed the bubble by about 50 ms, so the app gave it
a stiffer one).
