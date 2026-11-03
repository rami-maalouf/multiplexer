# A popover menu inside a list section becomes its cells

**Status:** Open
**Systems:** Apple host (lists), contract compiler
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A list of waiting messages gave each row a menu (Send Now, Change Time, Cancel), written
beside the row's button inside the row's `for`:

```contract
list listStyle="inset-grouped"
  section
    for m in messages key=m.id
      button popovertarget=`menu-${m.id}`
        ...
      column id=`menu-${m.id}` popover="auto" role="menu"
        button press=sendNow(m.id) ...
```

Opened, the menu's buttons drew as more cells of the section, under the row, with
separators. The build gave no warning. Moving the `for` of menus out of the list, beside it in
the screen's column (as other menus in the app are), made each a proper menu.

Cost: about 5 minutes.

## What would help

- A compiler warning for a `popover` inside a list `section` (or the host lifting it out of
  the list, as it does for a menu elsewhere).

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5).
