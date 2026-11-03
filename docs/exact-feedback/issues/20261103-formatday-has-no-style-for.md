# `formatDay` has no style for a chat's day label: Today, Yesterday, the weekday in the last week, then the date

**Status:** Open
**Systems:** standard functions (`formatDay`), dates-and-days recipe
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat transcript labels its days as Messages and other chat apps do: "Today", "Yesterday", the
weekday within the last week ("Monday"), then the date ("Oct 29, 2026"), with the time after it.
`formatDay` has `"day"` (Today, Yesterday, then the date: no weekday), `"day-time"` (the same with
" at " and the time) and `"list"` (the weekday two to six days back, but a time for today and
"10/11/26" after a week). None gives the chat's label, so the app counts days itself:

```contract
fn dayNumber(t: number, offset: number): number = floor((t + offset * 60000) / 86400000)
fn dayName(t: number, now: number, offset: number): string = dayNumber(now, offset) - dayNumber(t, offset) < 2 ? formatDay(t, now, offset, "day") : (dayNumber(now, offset) - dayNumber(t, offset) < 7 ? formatDay(t, now, offset, "list") : formatDate(t, offset, "medium"))
```

The same app also writes "Seen yesterday" and "Seen Monday" under a read message, from the same
pieces.

Cost: about 5 minutes.

## What would help

A `formatDay` style for it (for example `"recent"`: Today, Yesterday, the weekday up to six days
back, then the medium date), and the dates-and-days recipe naming it for a chat's or a feed's
day labels. Which name and which rule is a design question for the Exact team.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0` (`bun exact.mjs contract vocab formatDay`).
