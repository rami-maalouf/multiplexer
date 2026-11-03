# A sheet's bar search field hides the bar and its Send while searching, and the search card does not say so

**Status:** Open
**Systems:** apple host, docs
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A sheet that sends what the person picks (a list of conversations to send a message to, with a
Send button in its `header`) had its search field in the `header`, as the search vocab card
shows. On iOS that is UIKit's search controller: while the person searches, it hides the sheet's
navigation bar, and the Send button with it. A drive checked a row in the results and could not
tap Send ("tap #…: ScrollView, in node #…, covers its middle"); a person would have to cancel the
search first. In an iOS 26 half-height sheet, the bar's search field also sits at the sheet's
bottom edge, under the content's own bottom row (a strip of tabs), which looked wrong for a
picker whose search belongs at the top.

Moving the `input type="search"` out of the `header` into the sheet's content kept the bar and
its Send, and put the field at the top.

Cost: about 10 minutes and three drives.

## What would help

- A line in the search card: in a sheet whose bar holds a Save or Send, the bar hides while the
  person searches; put the field in the content to keep it (and in a half-height sheet the bar's
  field sits at the bottom).
- Or a prop for UIKit's `hidesNavigationBarDuringPresentation`.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5).
