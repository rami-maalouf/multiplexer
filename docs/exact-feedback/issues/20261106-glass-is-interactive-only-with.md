# Glass is interactive only on a node with its own `press`, and the docs do not say so

**Status:** Open
**Systems:** docs, Apple host, agent
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-06

## What happens

A chat screen has two liquid-glass surfaces that the product owner wanted to respond to a held
finger as iOS 26's interactive glass does (it swells and follows the finger): a capsule under the
chat's title, inside a `button` that opens the chat's info, and the composer's field, a glass
`column` around a `textarea`. Neither did. Nothing in the docs or `contract vocab` said why.

The host's source did (`NodeViewIOS.swift`, `updateMaterial`): `UIGlassEffect.isInteractive` is
set only when the node with `backgroundMaterial="glass"` declares `press` itself and is not
disabled. A press on an ancestor (the title's `button`) does not count, and a glass box with no
press never becomes interactive. The fix was a `press` on each glass node (the same action as the
button's; the innermost pressable wins, so it fires once), plus `-exact-press-opacity=1` so the
host's press dim does not fight the glass's own response.

The agent could not show the result: `tap <glass> down` and a screenshot held for 500 ms showed no
pixel change, as the agent's touches reach the host's own gesture handling, not UIKit's glass
interaction. So the effect is checkable only with a finger on a device.

Cost: about 15 minutes, with the host source read.

## What would help

- A line on `backgroundMaterial="glass"` in the reference: "glass is interactive (iOS 26) when the
  same node has `press`; give the glass node its own `press`, and consider
  `-exact-press-opacity=1`".
- An agent `state` or `layout native` field naming whether a glass effect is interactive, as it
  already names `effect=glass`.

## Evidence

Seen on 2026-11-06 at exact2 `ae8946aca0` (iOS Simulator, iOS 26.5, a 402x874 iPhone).
