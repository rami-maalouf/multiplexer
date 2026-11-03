# A labelled image inside a link row is left out of the row's VoiceOver label

**Status:** Open
**Systems:** Apple host, accessibility
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

A chat list's row is a `link` > `row`. On the corner of the row's picture sits a small brand
logo: `image "assets/<brand>.svg" width=15 height=15 aria-label="<Brand>"`, in an absolutely
placed `view`. The brand is information that the row's texts do not repeat.

On iOS, `agent ios "tree --ax"` reads the link as its texts joined:
`link "MN <name> 5:20 PM You: <last message>"`. The image's label is not in it. On the web, an
image's label counts in its link's accessible name.

A second try, `role="img" aria-label="<Brand>"` on the logo's box with the image
`aria-hidden=true`, read the same.

No doc says which children a row's spoken label joins, and none shows a way to add one word to
it without writing the link's whole `aria-label` by hand (and so repeating its name, time,
last message and unread count).

Cost: about 10 minutes; left as it is, with the label on the image.

## What would help

- A labelled image (or a `role="img"` box with a label) counting in its link's spoken label,
  as on the web.
- Or a doc line that names the rule, and the way to add a word to a row's label.

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0` (iOS Simulator).

## Pull request (2026-11-03)

https://github.com/ccheever/exact2/pull/1407 (fixes it): a link's spoken name joins each
descendant's own label in place of its content, as accname's name from content does. In a drive of
a minimal app: before, `link "AL Ada Lovelace You: see you soon"`; after, `link "AL WhatsApp Ada
Lovelace You: see you soon"`. The words a node shows (bar titles, segments) are unchanged.
