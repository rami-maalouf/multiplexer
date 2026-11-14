# A wrapped row in a list section has a tall gap between its lines

- date: 2026-11-14
- severity: P3
- cost: about 6 minutes

A grouped list's section holds a `row gap=8 flex-wrap="wrap"` of buttons (`flex="1 1 40%"`), so
at the accessibility text sizes they wrap two to a line. On iOS the space between the wrapped
lines is about 38 points, while the space between two buttons on a line is the expected 8. An
explicit `row-gap=8` changed nothing, and the contract build accepted it without a word. The same
gap shows on an older page with four such buttons, so it is not new to one layout.

What would help:
- A wrapped row honoring `gap` (or `row-gap`) between its lines, as the web does.
- Or a lint or a refusal that names the property the host ignores.

No app name, account or message content is included.
