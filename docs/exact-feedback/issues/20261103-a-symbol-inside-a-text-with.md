# A symbol inside a text with no width or height draws nothing, with no warning

**Status:** Open
**Systems:** Contract lowering, Apple host, symbols recipe
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat list marks a muted chat with a small crossed bell right after its name, which can wrap
to two lines. A `row` of the name `text` and the `image "symbol:..."` puts the symbol at the
right edge of the name's box when the name wraps, not after its last word, and at the largest
text size it squeezes the name until a word spills (`check`: "its text is 5 pt wider than its
box"). So the symbol goes inside the text, as LLP 1011.002 allows for an image:

```contract
text font="-exact-headline" flex="1 1 10rem" min-width=0
  text r.name
  if r.muted
    text " "
    image "symbol:icon.bell-slash" font="-exact-footnote" color="-exact-secondary-label" aria-label="Muted"
```

The build gives no error and no warning, and on iOS the symbol is not drawn: no bell, in every
row. LLP 1011.002 D2 explains it: an inline image with no `width` or `height` takes its natural
size, "else zero"; a symbol reports none there, and `font` does not size it. With
`width="0.8em" height="0.8em" vertical-align="baseline"` (and no `font`) the symbol shows after
the last word, at every text size, light and dark, and `check` is clean.

Cost: about 20 minutes (three builds and drives, then reading the LLP after finding the closed
issue `20261022-no-image-inside-a-text-paragraph.md`).

## What would help

- A warning when a `symbol:` image inside a `text` has no `width` and `height`: it draws at zero
  size (or a symbol there taking its size from `font`, as it does in a `row`).
- One line in `docs/recipes/symbols.md`: a symbol after a text's words (a muted mark after a
  title) is an `image` inside the `text`, with `width` and `height` in `em` and
  `vertical-align`. The only example today is `apps/excord`'s raster emoji.

The recipe line is a pull request candidate; the warning is for the Exact team.

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0` on the iOS 26.5 Simulator
(`bun exact.mjs contract build app.contract --json` returned `[]`, then drives with
`screenshot`).
