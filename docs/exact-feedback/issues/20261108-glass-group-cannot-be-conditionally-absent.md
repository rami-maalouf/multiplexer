# glassGroup cannot be conditionally absent

**Status:** Open
**Systems:** compiler, glass
**Severity:** P3
**Date:** 2026-11-08

A platform workaround needs a glass group on one host and no group on another.
`glassGroup=(enabled ? some(8) : none)` is refused with `lower-attr-type`:
"`glassGroup` takes a number; this expression is `option<number>`".

Cost: about 3 minutes checking component slots. A slot wrapper selects two rows,
one with `glassGroup=8` and one without it, sharing the caller's controls.
Allowing an optional group value to remove the group would avoid the wrapper.
