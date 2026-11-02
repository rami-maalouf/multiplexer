# A picked HEIC photo over 256 KB shows as an empty image, with no log line

**Status:** Open
**Systems:** apple host, image, media picker
**Severity:** P2
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-02

## What happens

A chat app shows the photos picked for the next send in a tray: `input type="file"
accept="image/*" multiple`, then `image <the Picked path under app:/tmp/picked/>` for each.

1. In an `agent ios` drive, two photos were picked: a JPEG and a HEIC of 455 KB. The JPEG
   showed; the HEIC's tile stayed empty. A HEIC of 42 KB in the same drive showed.
2. The drive's log had no line about the failed picture.
3. From reading the host (not measured): `RasterInput` reads the file's first
   `RasterMetadata.headerLimit` bytes (256 KiB, `RasterImage.swift:63`;
   `RasterInput.swift:153`) and gives them to ImageIO. When ImageIO answers no pixel size
   from that part, `RasterMetadata.read` throws `RasterFailure.headerLimit`
   (`RasterImage.swift:135`: "no image size in its first 262144 bytes"). ImageIO seems to
   answer a HEIC's size only from the whole file, so every HEIC over 256 KiB fails.

`accept="image/*"` keeps HEIC (the picker turns HEIC into JPEG only when `accept` names
images but not HEIC). An iPhone photo is a HEIC of 1 to 3 MB, so the plain photo picker
cannot preview the person's own photos.

Cost: about 10 minutes and two drives. The app now lists its image types without HEIC
(`image/jpeg,image/png,image/gif,image/webp`), so the picker hands over a JPEG.

## What would help

- For a HEIC (or any file where ImageIO answers no size from the prefix), read the
  whole file before giving up; the encoded-size limit still holds.
- A log line in the drive when a picture fails, with the `RasterFailure` text.
- Until then, one sentence in the picker doc: `image/*` keeps HEIC, which `image` shows
  only under 256 KiB.

## Evidence

Seen on 2026-11-02 at exact2 `ed43ad09a0`, `agent ios` on an iOS 26.5 Simulator. A HEIC
of 42 KB showed; one of 455 KB did not; a JPEG in the same tray showed.
