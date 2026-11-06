# A drive without real touches draws a menu without the menu

**Status:** Open
**Systems:** agent (iOS drive), Apple host (menus)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

On iOS, a long-press menu (`contextmenu=` with `contextPopover=`) and a tap menu
(`popovertarget=` on a `column popover="auto" role="menu"`) opened in a drive without
`--touch platform` drew as bare rows over the screen: the menu's items in the accent colour,
no background, no lifted control. `screenshot <png> window` (the display's own pixels) showed
the same. I took it for a broken menu and tried three other ways to look at it.

With `--touch platform` (`tap <id> down`, a real wait, `screenshot <png> window`, `tap up`;
or a real tap for a `popovertarget`), both are proper `UIMenu`s on their platter, the
long-pressed control lifted.

Cost: about 12 minutes and five drives.

## What would help

- The drive saying, when it opens a menu without real touches, that it draws the menu's rows
  itself and that `--touch platform` shows the system's menu; or drawing the system's menu.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5): `tap <id> contextmenu` and `tap <id>` (a `popovertarget`), each followed by `screenshot ... window`.

## More evidence (2026-11-06)

A tap on a filter button (a `popovertarget` menu of five radio items), then `screenshot ... window`,
showed the five items as bare accent-coloured words over the list's rows. A real-touch check showed
the system's menu drawn right. It cost about 6 minutes, including a second sign-in. Exact `dd9343b324`.
