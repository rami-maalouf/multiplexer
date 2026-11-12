# Verify accept cannot take a template testId

**Status:** Open
**Systems:** verify
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-07

## What happens

`"verify": {"accept": [{"finding": "fixed-type", "node": "phone-*", ...}]}` takes the fixed
type of a `text` with a literal `testId="phone-clock"`, but not of a `text` inside a `for`
whose `testId` is a template (`` testId=`phone-name-${c.id}` ``): those lines stay counted.
The text is a drawing of a phone (`role="img"`), where a fixed size is the design.

Cost: about 5 minutes. Workaround: one fixed `font-size` on the rows' parent, `em` sizes on
the texts.

## What would help

Match a template `testId` by its literal prefix (the part before the first `${`), or say in
the verify summary that a template id cannot be accepted.

## Evidence

Seen on 2026-11-06 at exact2 `31063d7dbb`, `verify` on a web landing page.
