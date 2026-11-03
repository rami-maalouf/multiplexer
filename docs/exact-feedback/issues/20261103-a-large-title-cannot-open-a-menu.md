# On iOS a route's title cannot open a menu, and the ways that look like they should fail quietly

**Status:** Open
**Systems:** Apple host (navigation bar, `NavigationTitleIOS.swift`, `MenusIOS.swift`), Contract lowering (`lower-header-no-bar`), docs (`contract vocab header`, `menu`)
**Severity:** P2
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat app's inbox has a large title, and the title opens a small menu (Select, Merge,
Settings), as another chat app on iOS has it and as UIKit gives with
`navigationItem.titleMenuProvider`. Three ways to write it, each from the docs' words:

1. A `button popovertarget="title-menu"` around the header's `text role="heading"`. It builds with
   `lower-header-no-bar`: "this route's `header` holds no heading, so on iOS it is not the
   navigation bar". The heading is one box down, inside the button. The iOS host's
   `HeaderTitle` does walk into a pressable wrapper; the compiler's walk does not.
2. A `row press=openTitleMenu` around the heading. It builds clean, and the host draws the title
   as a `HeaderTitleView`, but on iOS 26 the bar then shows the title twice: a centred inline
   title above the large one. Its press runs, and the action's
   `showPopover("title-menu", source="title-button")` is logged
   (`command showPopover("title-menu", "title-button")`), yet no menu shows, whether the menu's
   column is in the header or in the route beside it. Nothing says why.
3. The docs: `contract vocab header` mentions "a pressable title" only for the Mac, and
   `contract vocab menu` says that a menu button "in a `header`" is "the bar item's
   pull-down". Whether the title itself can open a menu is answered only in a draft RFC,
   LLP 1141.003 D3, which designs it and is not built.

Cost: about 30 minutes over three tries, reading `NavigationTitleIOS.swift` and the RFC.

What the app did instead: the route says `navigationBar="none"` and draws its own top row, a
`button popovertarget` holding the title's words and a chevron, which is UIKit's pull-down from
a page button. It works and looks like the other app's title, but the screen lost UIKit's large
title (the collapse on scroll and the bar's material) and needed `min-height=44` and its own
padding.

## What would help

- LLP 1141.003 D3, the title menu (`titleMenuProvider`).
- Until then: a warning when a popover is shown from the bar's title, or from a `source` in the
  bar, that cannot show there; no second inline title for a pressable large title; and one
  line in the header card on what a button around the heading does on iOS today.
- `lower-header-no-bar` naming the heading it found inside the button, and saying that the
  title cannot be a button yet.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0` on the iOS 26.5 Simulator, in drives with
`--chrome platform` and `--touch platform` (`screenshot … window`): the doubled title, the
logged `showPopover` with no menu, and the page row's working pull-down.
