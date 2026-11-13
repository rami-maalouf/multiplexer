# Long identifier wrapping needs a specific remedy

- date: 2026-11-12
- severity: P3
- cost: about five minutes and two native drives

A profile subtitle containing a long identifier overflowed at the largest accessibility
text size. `max-width="100%"` constrained its box but left the text clipped.
`overflow-wrap="anywhere"` fixed the overflow but verify rejected it as breaking words,
with a generic recommendation to wrap between words or give the row room.

Inspected `brokenWordsIn` in `scripts/no-tells.mjs` to understand the distinction.
`overflow-wrap="break-word"` is appropriate here: ordinary words retain their boundaries,
while an overlong identifier can wrap within the available width. A diagnostic or recipe
that names this option for identifiers would avoid source inspection.

No source, account identity or message content is included.
