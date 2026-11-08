# On macOS the app traps in AppKit's glass layout after a send

**Status:** Open
**Systems:** macOS host, glass
**Severity:** P1
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-08

## What happens

On macOS 27.0.1, the app stops with `EXC_BREAKPOINT` (a SIGTRAP; the drive says "the app exited
(killed by SIGTRAP)") within a second of a tap on a chat composer's Send button. It happened in
each of 5 drives. The message is sent first. No crash report is written, and the system log has
no assertion text. With a debugger attached, the stop is inside AppKit's Liquid Glass layout,
called from the window's display cycle, with no Exact frame on the stack except `main`:

```
frame #0: AppKit`___lldb_unnamed_symbol_185dec2fc + 596   (brk #0x1)
frame #1: AppKit`___lldb_unnamed_symbol_185dd6fd4 + 508
frame #2: AppKit`NSGlassEffectContainerView.layout() + 2208
...       AppKit`-[NSView _layoutSubtreeWithOldSize:] (many levels)
frame #46: AppKit`-[NSWindow(NSConstraintBasedLayoutInternal) _layoutViewTree]
frame #50: AppKit`NSDisplayCycleFlush
frame #70: <app>`main at main.swift:926
```

The composer bar has glass parts: a "+" button, the field, a send button with
`backgroundMaterial="glass"`, and a voice button. After a send, the field empties, the send
button leaves, and the voice button takes its place. With the send button's
`-exact-exit-animation` removed, the trap still happens, now during the `tap send` op. Before
the trap, AppKit logs once: "It's not legal to call -layoutSubtreeIfNeeded on a view which is
already being laid out".

Cost: about 30 minutes. No workaround yet. A chat cannot be used on the Mac while it happens.

## What would help

Find which glass container change during layout makes AppKit trap: maybe a glass view added
to or removed from an `NSGlassEffectContainerView` while it lays out, or a layout pass that
starts inside another one, as the log line says. A small repro: a row of glass buttons in a
bottom bar, where a tap removes one button and adds another in the same commit.

## Evidence

Seen on 2026-11-08 at exact2 `86559f737a` (the macOS host), macOS 27.0.1 (26A434), Apple Silicon,
`agent macos --size 900x700 --chrome platform`, a send in a chat on a list-detail split.

## Follow-up

Reconfirmed on 2026-11-08 in the full app as a test account, with SIGTRAP after Send. Signed out afterward. Small account-free probes survive nested glass replacement, tint, entry/exit animation and intermediate frames. An authored test of the account-free probe crashed with SIGTRAP in 1 of 2 consecutive runs. Preserved in tools/mac-glass-probe/. The reduced crash has no stack yet; the shared failure mechanism remains unknown.

Public account-free crash probe: https://gist.github.com/rami-maalouf/670cc6083729abf9d089d5a938b38755 (intermittent, 1 SIGTRAP / 2 authored-test runs).
