# No keyboard fact: a chat cannot keep a message in view as the keyboard comes up

**Status:** Open
**Systems:** platform facts, keyboard
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

A swipe can start a reply on a message low on the screen while the chat is scrolled up. The
keyboard then comes up and the list gets shorter from the bottom, keeping its top, so the
message being answered ends under the keyboard. To keep it in view, the app must scroll after
the keyboard is up, but nothing tells it when: `exactViewport().height` stays the same (874
before and after, with `interactive-widget="resizes-content"`), and there is no keyboard fact.

What worked: on starting the reply, a task `after(300, revealNow, wait=idle, max=1000)` whose
action calls `scrollIntoView("transcript", id, block="nearest", behavior="smooth")`. A drive shows
the message just above the reply bar, but the delay is a guess.

Cost: about 15 minutes.

## What would help

- A keyboard fact (its height, or whether it is up), or a `resize` event on the list.
- Or a list that keeps its bottom rows in view when it gets shorter, as a chat needs (Messages
  does this when the keyboard comes up).

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0` (iOS Simulator, iOS 26.5).
