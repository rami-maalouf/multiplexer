# `contract vocab clipboard` does not name the image clipboard

**Status:** Open
**Systems:** contract vocab, @exact/clipboard
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat app wanted Copy for a held photo. `contract vocab clipboard` answers: "`clipboard` is
not a tag ... copying is the host command `copyText(text)` (`contract vocab copyText`)", and
`contract vocab copyText` names only the host command. So I wrote a native module op that put
the picture on `UIPasteboard`. It worked; then `docs/contract-grammar.md` (under the copy
events) showed `@exact/clipboard`: data code writes a `ClipboardItem` of a PNG, and
`storage.fs.compressImage(..., {type: 'image/png'})` converts a JPEG first. That needs no native
code, so I removed the op.

Cost: about 10 minutes and one Swift build of a native module.

## What would help

- `contract vocab clipboard` (and `copyText`) naming `@exact/clipboard` for an image, with its
  PNG-only rule and the `compressImage` step.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`.
