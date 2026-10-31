# a long-press menu has no row of reactions

**Status:** Open
**Systems:** contract menus, iOS host
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-10-31

## What happens

A chat app's long press shows a row of quick reactions above the message and actions
under it (Messages, WhatsApp and other chat apps do). A `contextPopover` menu is a `UIMenu`
of rows, with no palette, so the app draws it by hand after the sample chat app: a
`contextmenu=` action, the bubble again under `contextTarget` and `contextMagnify`, a blur
(`backgroundMaterial`), the reactions and the actions, and `inert` on the chat under it.
It works and `check` is clean, but it is about 40 lines that each chat app writes again,
and the system's navigation bar stays sharp above the blur.

## What would help

A palette section in a long-press menu (`UIMenu`'s `.displayAsPalette` on iOS), or a
documented pattern for a message's long press.

## Evidence

Seen on 2026-10-31 at exact2 `1bc4c36cb7`.
