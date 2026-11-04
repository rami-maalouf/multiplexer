# A drive cannot tap a row of an open menu that runs past the screen

**Status:** Open
**Systems:** agent, menus
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat list's row has a long-press menu (`contextmenu=… contextPopover="chat-menu"`, a `column
popover="auto" role="menu"`). In a drive, `tap <row> contextmenu`, then `tap menu-remind` on one of
its rows, failed: "tap #688: its middle is outside the viewport; scroll it into view first". The row
behind the menu was near the bottom of the screen at that moment, and a menu row cannot be
scrolled. The same steps worked when the held row was higher on the screen. `tree --ax` listed the
menu row.

I drove the same action from another screen's menu instead.

Cost: about 5 minutes.

## What would help

- The menu kept on the screen, as UIKit places a context menu, or the refusal saying the row is in
  an open menu that runs past the screen.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS 26.5 simulator.
