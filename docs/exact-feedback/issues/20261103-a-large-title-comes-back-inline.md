# A large title comes back inline when a route with no bar turns into one with a large title

**Status:** Open
**Systems:** Apple host (navigation bar, large titles)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

An app's first route shows a sign-in form while signed out (a `header` with an `aria-level=1`
heading over a grouped list) and a list while signed in. The list draws its own top row, so
that branch says `navigationBar="none"`. Both branches are the same route (`navigationKey`
of the stack entry). From a pushed settings screen, Sign Out pops the stack to that route
(`nav = go(nav, path("home"))`) as the session ends, so the route turns from the list into the
sign-in form.

The sign-in form's title then shows inline and small, centred in the bar. On a fresh launch,
signed out, the same screen shows it large. Popping in the same action as the sign-out, or in
the sign-out's `then`, made no difference.

Cost: about 8 minutes. Not fixed: it shows only right after a sign-out.

## What would help

The bar coming back with its large title expanded when a route that had no bar gets a
large-title header (UIKit keeps the last collapsed state of a hidden bar), or a word on how to
ask for it.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0` on the iOS 26.5 Simulator, in drives with
`screenshot … window`: the inline title after Sign Out, and the large one on a fresh launch.
