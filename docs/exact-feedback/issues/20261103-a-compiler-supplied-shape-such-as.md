# A compiler-supplied shape such as Picked cannot be built or looked up

**Status:** Open
**Systems:** contract compiler, contract vocab
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A chat app keeps the photos and files chosen for the next message as a list of records that hold
a `Picked` (the file picker's `change` answer). A photo from `@exact/camera` (`Photo`: path, type,
size, width, height) had to join the same list. Two walls:

```
contract vocab Picked
  -> `Picked` is not a tag, an attribute, a standard function, a recipe or a pattern; try
     `contract vocab select` (a concept)
Picked(path=p.path, name=…, type=p.type, size=p.size, width=some(p.width), height=some(p.height), duration=none)
  -> `Picked` is not in the stdlib roster and is not an action; data comes from a `resource`
```

The fields were only in the media picker's design note (LLP 1069.002, D3). The app added a shape
of its own with the same fields, mapped each pick into it with a function, and changed its data
module's type: four edits across three files.

Cost: about 15 minutes.

## What would help

- `contract vocab` answering the compiler's own shapes (`Picked`, `exactViewport`) with their
  fields.
- A `Picked` an app can build, or the camera's `Photo` able to stand for a `Picked`, so one list
  holds a picked photo and a camera photo.

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`.
