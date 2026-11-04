# A page opened from a sheet with go stays in the sheet

**Status:** Open
**Systems:** navigation, Apple host (sheets)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat app's inbox opens a half-height sheet (`navigationPresentation="modal"`,
`navigationDetent="medium large"`) with one row per list. One row opens a page of saved
messages: a route under the root, not under the sheet's route. Its action was
`nav = go(nav, path("saved"))`. The stack became root, sheet, page (`state nav`), so the page
showed inside the sheet. A tap on one of the page's rows opened a chat with
`go(nav, path("room", id))`, and the chat opened inside the half-height sheet too, with its
composer, as `screenshot` showed. Nothing warned; `check` found nothing.

`nav = push(back(nav), path("saved"))` closed the sheet and pushed the page, and the chat then
opened full screen over it.

Cost: about 5 minutes.

## What would help

`go` to a route that is not under the sheet's route closing the sheet (the URL says the page
is not the sheet's), or `check` naming a full-screen route drawn inside a sheet. Failing both,
a line in the navigation guide: "to leave a sheet for a page, `push(back(nav), …)`".

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS 26.5 Simulator, in drives with `state nav` and
screenshots: the stack after `go` kept the sheet's entry, and the chat showed in the sheet.
