# Verify's contrast check ignores a gradient fill

**Status:** Open
**Systems:** verify, web
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-07

## What happens

A pill link whose fill is `background-image` (a three-colour gradient) with dark text on it
(about 6:1 against every stop) is reported by `verify` as `contrast ... 1.2:1 (#0c1118 on
#152a2f), needs 4.5:1`: the check reads the page under the pill, not its gradient. Numbered
circles filled the same way are reported at 1.1:1. Each needs a `verify.accept` entry.

Cost: about 3 minutes.

## What would help

The check measures text against the lowest-contrast stop of a `background-image` gradient on
the text's own box or an ancestor's, as it does for a `background-color`.

## Evidence

Seen on 2026-11-06 at exact2 `31063d7dbb`, `verify` on a web landing page.

