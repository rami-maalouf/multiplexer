# A header search field has no close event, and a drive cannot press it or its close button

**Status:** Open
**Systems:** apple host, agent
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat list wanted the search of the original app: a round search button in the list's bottom
bar turns into a search field at the bottom, the keyboard up, and a round close button (X) ends
the search and shows the list as it was, in one tap.

A route `header` with `input type="search"` (no tab bar) became UIKit's search field at the
bottom of the screen, and while active it had UIKit's round close button beside it: the look
wanted. But:

- Exact passes no close event. Closing gives the field's `input` with "" and a `blur`. A drag
  that puts the keyboard away with the field empty gives the same, so an app cannot end its
  search on close without also ending it on a scroll.
- The field is always shown at rest at the bottom: there is no way to show a search button in a
  bar that expands into the field (UIKit's iOS 26 `searchBarPlacementBarButtonItem`), so it
  overlaps an app-drawn bottom bar.
- A drive could not press the field (`tap probe-search`: "bar item #7 is disabled or presses
  nothing"; `type` worked) nor UIKit's close button, so a close could not be tested.

The app draws the field in its own glass bar, with `input type="search"` and its own close
button. Cost: about 20 minutes (a probe build and three drives).

## What would help

- A `cancel` event on a header search field (UIKit's `searchBarCancelButtonClicked`, or
  `didDismissSearchController` when the search was active).
- A way to place the header's search as a button in a bottom bar that expands into the field.
- A drive op that presses a header field and its close button.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5), a phone.
