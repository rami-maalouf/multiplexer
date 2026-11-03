# A disabled menu row with no press is dropped from the iOS menu

**Status:** Open
**Systems:** Apple host (`MenusIOS.swift`, `items(of:)`), Contract lowering, docs (`contract vocab menu`)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A menu shows two features that come later as greyed rows, and one that works:

```contract
column id="title-menu" popover="auto" role="menu"
  button disabled=true testId="menu-select"
    image "symbol:select"
    text "Select"
  button press=settings popovertarget="title-menu" popovertargetaction="hide"
    image "symbol:settings"
    text "Settings"
```

On iOS the pull-down showed Settings alone. The host turns a row with no press handler into a
section break, and applies `disabled` only to a row that presses. `contract vocab menu` says
"an `hr` between rows starts a section" and "`destructive=true` paints a row red", but not that
a row with no press is a break too, and the compiler says nothing. On the web the same row shows,
greyed.

Cost: about 5 minutes, found by reading the host's source.

Workaround: the greyed rows say `press=settings`, which a disabled row never runs.

## What would help

- A `disabled=true` row kept as a dimmed action whatever its handlers (HTML's disabled button).
- Or a warning: "this menu row has no press, so iOS shows it as a section break".

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0` on the iOS 26.5 Simulator under `--touch platform`
(`presented="menu"`): before the workaround one row, after it three, two of them greyed.
