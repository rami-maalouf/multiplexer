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

## More evidence (2026-11-02, `1bc4c36cb7`)

The navigation bar is not only sharp above the hand-drawn menu: it stays live. A real tap
on its Back button (`--touch platform`, `tap root at 37 84`) pops the route while the menu
is open. The app's `back` action did not clear the menu's state, so the chat opened again
with the menu already up. The sample chat app clears its selection in `back`; nothing says
why. A menu that is modal over the bar, or a line in a recipe that `back` must close what
the screen holds open, would have prevented it.

## The sharp bar: gone with the app's own bar (2026-11-03, `ed43ad09a0`)

The chat screen now draws its own top bar (`navigationBar="none"`) instead of the system's, for
its look. The hand-drawn menu's blur is in the same route, so it covers that bar too, in light
and dark, and the bar takes no tap while the menu is open (`inert`). The blur box reaches past
the route's top and bottom (`top=-120`, `bottom=-60`) to cover the status bar's and the home
indicator's areas. The palette request above stands: the menu is still about 40 lines by hand.

## Seen again (2026-11-03, `ed43ad09a0`)

The app-drawn menu grew from two rows to seven (and a separator), which brought three costs a
system menu would not have:

- With `backgroundMaterial="glass"`, the menu's Liquid Glass bent the lifted bubble just above it
  into a band of blue and squashed text along its top edge (on the display too). A UIKit blur
  (`backgroundMaterial="material"`) removed it; a system menu keeps its preview apart.
- At the accessibility text sizes the lifted copy and seven rows no longer fit: the app caps the
  copy's height (a photo shrinks to fit), gives the menu the room left and makes it a `scroll`.
- `check` now calls the overlay's full-screen dismiss layer "covered" (the menu covers its
  middle), a design the system menu does not need.

About 40 minutes over the three.
