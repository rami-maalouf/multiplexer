# A search field in content gets the web address keyboard

**Status:** Open
**Systems:** apple host, docs
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

An `input type="search"` in a screen's content (a search field drawn at the bottom, not in the
`header`) got iOS's web-search keyboard (`UIKeyboardType.webSearch`, `NativeFieldsIOS.swift`):
a "." key beside the space bar, and an arrow on the return key even with
`enterkeyhint="search"`. UIKit's own search bar, which a header field becomes, uses the plain
keyboard with a Search key. A chat search wants the latter.

`inputmode="text"` gave the plain keyboard and the Search key. Nothing in the search docs says
so. Cost: about 3 minutes.

## What would help

`type="search"` taking the plain keyboard with the Search key, as UIKit's search bar does (and
`inputmode="url"` for an address field), or a line in the search card naming `inputmode="text"`.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5), a phone.
