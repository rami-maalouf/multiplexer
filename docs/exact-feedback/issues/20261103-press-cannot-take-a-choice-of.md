# `press=` cannot take a choice of two actions

**Status:** Open
**Systems:** Contract compiler
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A full-screen page's bar has one Close button. While a search is open on the page, the same
button closes the search instead. The natural form is refused:

```contract
button id="back" press=(searching ? closeSearch : close) aria-label=(searching ? "Close Search" : "Close")
```

"`press=` needs an action name or `action(args)`". The other attributes of the same button
take the condition. The workaround is an `if`/`else` with two buttons that differ only in
`press`, `aria-label` and `testId`.

Cost: about 1 minute, and a repeated button.

## What would help

- `press=` (and other action props) taking a choice of two actions, as value attributes take a
  choice of two values.
- Else, the refusal showing the `if`/`else` form.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5).
