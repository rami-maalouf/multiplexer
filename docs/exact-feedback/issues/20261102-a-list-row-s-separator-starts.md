# A list row's separator starts at the initials inside its round picture

**Status:** Open
**Systems:** Apple host, lists
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

A chat list is a plain `list` (no `appearance`). Each row is a `link` > `row`: a 44-point round
picture (`view border-radius=22 overflow="hidden"`) that holds the chat's initials as `text`
when it has no photo, then a column with the chat's name, time and last message.

On iOS the separator under each row starts at the left edge of the initials, so the separators
jump left and right from row to row ("MM", "IB" and "MN" are of different widths, so their
lines start at different x). A row whose picture is an `image` has its line at the name, as
Messages draws all of them. One try, `aria-hidden=true` on the initials, changed nothing.

The contract guide says to draw none of a list's separators, `contract vocab separator`
answers nothing, and no doc says where a plain list's separator starts. Reading the host
(`GroupedListIOS.swift`, `itemSeparatorHandler`, `lineStart`) and the kernel's
`grouped_separator`: the rule "after a leading symbol, at the text" covers only a `symbol:`
image.

This is known: exact2's `QUEUE.md`, "A list's rows as cells, what is owed", (2): "A separator
starts at the row's first text; a row whose first text is not its title starts there all the
same." This file adds a common case: initials inside a round picture, which most chat and
contact lists have.

Cost: about 15 minutes; left as it is.

## What would help

- The separator starting at the first text after a leading picture of any kind (a box that
  holds an image or initials), as UIKit's own cells do beside an image.
- Or a documented way for the row to say where its line starts.

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0` (iOS Simulator, dark and light).
