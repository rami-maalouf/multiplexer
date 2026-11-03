# iOS adds a hyphen inside a link's address under `break-word`, and an inline run's `hyphens` is dropped

**Status:** Open
**Systems:** Apple host (text layout), Contract lowering, docs (`hyphens`)
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat bubble's text is a paragraph with `overflow-wrap="break-word"` (as the sample chat app
and the `chat-thread` recipe's fix have it), and a link in it is an inline run with `press`:

```contract
text white-space="pre-wrap" overflow-wrap="break-word"
  for r in runs key=r.id
    if r.href != ""
      text r.text color="AccentColor" text-decoration-line="underline" press=open(r.href)
    else
      text r.text color="-exact-label"
```

On iOS a long address broke inside a word with a hyphen added: "wiki/Ma-" / "trix_(protocol)",
and at the largest text size a domain name broke the same way (as "www.some-" / "site.com" for
"www.somesite.com"). The address on screen then reads as
another address. The docs say `hyphens` is `manual` by default and that `manual` breaks only at
soft hyphens, so the hyphen was a surprise. Exact's source explains it: on iOS,
`ParagraphGeometry.insertsHyphens` turns on emergency hyphens for `hyphens == manual` with
`overflow-wrap == break-word`.

`hyphens="none"` on the link's run changed nothing: the paragraph's `hyphens` counts, and a
run's is dropped with no warning. `hyphens="none"` on the paragraph fixed it.

Cost: about 15 minutes (two drives, then reading the host's source to find the rule).

## What would help

- The `hyphens` docs (contract-for-agents, "Book typography") saying that iOS hyphenates an
  overlong word in a `break-word` paragraph, and that `hyphens` is a paragraph's property. This
  part is a pull request candidate.
- A warning when an inline run sets `hyphens` (or the run's value applying to its own words).
- No emergency hyphen inside a run that is a link, or inside a word that looks like an address:
  Safari and Messages never hyphenate a URL.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0` on the iOS 26.5 Simulator, in drives with
`screenshot` (default text size, and `accessibility-extra-extra-extra-large`).
