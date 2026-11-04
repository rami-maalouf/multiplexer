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

New evidence (2026-11-03, `ed43ad09a0`, another screen of the same app): a user id with no
spaces (`@name:server.example`) in a settings row, at the largest text size, broke with a hyphen
inside the server's name ("ra mi-" / "maalouf.co" / "m"), with no `overflow-wrap` written.
`hyphens="none"` took the hyphen away but not the break inside the word.
`overflow-wrap="anywhere"` broke it cleanly, but `verify ios` flags that ("breaks inside words
(Octo/ber); wrap between words (the default) or give the row room"), and with neither, `check`
flags the row running 140 pt past the screen. For a word longer than any line, the two checks'
remedies do not fit. What worked: a zero-width space after the colon and each dot
(`userId.replaceAll(":", ":\u200B").replaceAll(".", ".\u200B")`), so the id breaks between its
parts. About 10 minutes. What would help as well: the `verify` finding naming what to do for an
identifier, an address or a URL (a `wbr`, or break opportunities after punctuation, as Safari
gives a URL).

## More evidence (2026-11-03, a filter sheet's rows)

The same hyphen on plain words, outside a link: a sheet row's name with `overflow-wrap="break-word"`
(added so that one long word stops spilling at the largest text size) showed "Insta-gram" and
"Commu-nity" on iOS, both words that broke only because of the hyphen rule. The row moved its
count under the name at the accessibility sizes instead, without `break-word`. About 5 minutes and
one drive. Seen at exact2 `ed43ad09a0`.

## More evidence (2026-11-04, a grouped action)

At the largest system text size, an inset-grouped action with a plus icon rendered its title as
`Create La-` / `bel`. Setting `hyphens="none"` on the child text, then also on its button, left the
display screenshot unchanged. Shortening the title to `New Label` kept the full text size and fit
without breaking a word. About 3 minutes. A grouped title's effective paragraph style should honor
the explicit setting, or the docs should identify the style owner. Feedback kept local.
