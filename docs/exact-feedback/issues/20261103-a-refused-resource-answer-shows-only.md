# A refused resource answer shows only in logs during a drive

**Status:** Open
**Systems:** agent (drives), data sources
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A data source answered one field more than its shape declares (a native module added a
timestamp the view does not use). The runtime refused the answer and kept the resource's old
value, an empty list. In a drive, `state <resource>` showed the empty list with no word, so the
feature looked broken in the view or the module. Only `logs` said: "`loadSaved` answered
outside its shape: field `items`: field `savedAt` is not in the shape". After that line the fix
took one edit.

Cost: about 3 minutes, and a drive.

## What would help

A refused answer named in the drive's own output when it happens (as a tap names what covers
it), or `state <resource>` saying that its last request was refused and why.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS 26.5 Simulator: `state` printed the old value;
`logs` printed the refusal.
