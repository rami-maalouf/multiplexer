# A route cannot say "a bar with buttons and no title" without an empty heading

**Status:** Open
**Systems:** compiler (`lower-header-no-bar`), Apple host, docs
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A full-screen profile page has Close on the left and Edit on the right, and no title: the name
is large in the page, under the picture. Its `header` with the two buttons warned:

> this route's `header` holds no heading, so on iOS it is not the navigation bar … Give it one
> `text role="heading"` (`aria-level=1` for a large title) — its buttons become the bar's items;
> or, for a site's header, say `appearance="none"` on it; or, if this screen draws its own
> chrome, say `navigationBar="none"` …

None of the three ways is "the system bar, with these buttons and no title". The app wrote
`text "" role="heading" aria-level=2` between the buttons: it builds with no warning and the
bar shows no title. It is a guess that may change meaning later.

Cost: about 3 minutes.

## What would help

- A way to say it: `navigationTitle="none"` on the route, or an empty heading named in the
  warning and in `navigation-stack.md` as the way.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`.
