# `go()` pushes a second entry of the same route instead of collapsing it

**Status:** Open
**Author:** Devin, from an external app friction log
**Systems:** router, navigation
**Severity:** P3
**Date:** 2026-11-09

A detail page (a chat member's profile) asks the app to open a different room.
`follow(path("room", otherRoomId))` pushed the new room on top of the stack:
`[home, room(A), member, room(B)]`. The member page stays reachable by Back, and —
worse for apps that derive the "open room" from the first `room` entry — the top
room renders the first room's resources.

Expected one of: `go` pops back to the existing `room` entry and applies the new
location (its doc hint "a pop to it on the selected stack" reads that way), or a
documented note that `go` never reuses an existing entry of the same route.

Workaround: collapse the stack by hand —
`nav = replace(back(nav), path("room", id))`, choosing the `back()` count by
`depth(nav)`. Cost: about 15 minutes and two verification drives.

What would help: a nav function that replaces the nearest entry of a named
route, or `go` reusing the same-route entry when the route is not parameterized
as a list→detail chain.
