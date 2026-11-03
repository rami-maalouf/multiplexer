# A search field in a sheet's content draws its magnifier over its text at the accessibility sizes

**Status:** Open
**Systems:** apple host, controls
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

An `input type="search"` placed in a sheet route's content (under its `header`, not in it)
draws its magnifier over its own placeholder at the accessibility text sizes: the placeholder
reads "🔍earch", the icon over its first letter. At the default text size the text starts clear
of the icon. It is the display's picture (`xcrun simctl io <udid> screenshot` while a drive held
the sheet open), not only the driver's own drawing.

- A `font-size` cap on the field (`min(-exact-body, 22px)`) did not change it.
- `padding-left=40` moved the text clear of the icon at the accessibility sizes, but at the
  default size the padding adds to the field's own inset, so the gap there doubles. The app now
  writes `padding-left=(largeText ? 40 : 0)` from `exactViewport().accessibilityTextSize`.

Cost: about 15 minutes and four drives.

## What would help

The field's leading text inset growing with its magnifier, as UIKit's own search field does at
every text size, so the app writes nothing.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iPhone, iOS 26.5), content size
`accessibility-extra-extra-extra-large`, dark mode, in two sheets (`navigationPresentation="modal"`,
one with `navigationDetent="medium large"`).
