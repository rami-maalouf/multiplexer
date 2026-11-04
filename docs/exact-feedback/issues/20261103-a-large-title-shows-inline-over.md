# A large title shows inline over a list with rows and large over an empty state

**Status:** Open
**Systems:** Apple host (navigation bar, large titles)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A pushed page has a `header` with a `text … role="heading" aria-level=1` title and
`navigationScroll` naming an inset-grouped `list`. When the list has rows, the title shows
inline and small, centred in the bar, from the first frame. When the page shows an empty state
instead (the list is not there), the same route shows the title large. The page was reached
the same way both times (pushed from another page with a bar), at rest, with nothing scrolled.

The app now uses `aria-level=2`, inline always, so the page does not change between its states.
Not isolated further.

Cost: about 3 minutes.

## What would help

The title starting large over a list at rest as it does over an empty state, or a line in the
docs on when a large title starts collapsed. It may share a cause with "a large title comes back
inline" (UIKit keeping a collapsed bar state).

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS 26.5 Simulator, with `screenshot`: inline over
two rows, large over the empty state.
