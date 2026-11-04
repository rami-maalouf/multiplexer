# A drive cannot reach a long-press menu row below the fold at the largest text size

**Status:** Open
**Systems:** agent (iOS drives), context menus
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A list row has a long-press menu (`contextmenu=aim(id) contextPopover="row-menu"`) with a
preview (`button contextPreview=true`) and seven rows, the last one `destructive=true`, which
opens a confirmation alert. At the largest text size
(`xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large`) UIKit's menu is
taller than the screen and scrolls, so its last row is below the fold.

- Under `--touch platform`: `tap <row> down`, `clock +1500 real`, `tap up` opens the real menu
  (the screenshot shows it), then `tap menu-delete` answers: "the menu of popover #245
  (row-menu) does not show its rows: tap its invoker first, then `clock settle`". The menu is
  open; its row is only scrolled out of view.
- Without the flag: `tap <row> contextmenu`, then `tap menu-delete` answers: "its middle is
  outside the viewport; scroll it into view first". No step is named that scrolls a menu.

So no drive reached the alert at that size, and its screenshot was skipped.

Cost: about 6 minutes.

## What would help

`tap` on a menu row scrolling the menu to that row first, as it scrolls a list row into view;
or, until then, the refusal saying that the row is below the fold of an open menu and how to
scroll it.

This is for the Exact team (the agent's behaviour), not a doc fix.

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0`, on the iOS 26.5 Simulator.

Seen again on 2026-11-03 at `ed43ad09a0`, at the default text size. `tap <row label> contextmenu`
first scrolled the row into view (`scrolled={"from":[190,2586],"to":[190,645]}` in a 874-point
window), which left it near the bottom; the menu opened under it, and `tap menu-archive` answered
"tap #590: its middle is outside the viewport; scroll it into view first". So the drive's own
scroll put the menu off screen. Workaround: make the row the list's first (a new message in
that chat), then hold it. About 2 minutes. A scroll that leaves room for the row's menu, or a
tap that scrolls the open menu, would remove it.

## seen again while adding a filter (2026-11-03)

At the largest system text size, a list's eight-action context menu again refused its lower
row with "its middle is outside the viewport". Dragging a visible action was also refused
because the synthetic menu's coordinates started above the viewport. With `--touch platform`,
the injected `contextmenu` was not UIKit's open menu, and the row was refused as "not the menu
UIKit shows". About 5 minutes. The same action was also exposed as a normal, scrollable
grouped row on an info page; that route passed light and dark checks at the largest text size.
This does not establish that the real menu's scrolling is broken.
