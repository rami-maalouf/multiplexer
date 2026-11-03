# The turn budget refusal does not name `exactBodyTo` for a large download

**Status:** Open
**Systems:** data module runtime (budget), docs
**Severity:** P3
**Author:** Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)
**Date:** 2026-11-03

## What happens

A mutation downloaded a GIF of about 6 MB from a public media host and saved it to send:

```ts
const response = await fetch(url);
const bytes = new Uint8Array(await response.arrayBuffer());
await storage.fs.writeFile('app:/tmp/gifs/x.gif', bytes);
```

It was refused: "`sendGif` took 344.3 ms of its own (CPU) time (345.3 ms of wall), over the
100 ms budget for one turn; a long loop can `await scheduler.yield()` every few thousand items
to go on in a new turn". There is no loop to yield in. I moved the download into a native
module, built it, and it worked. Later, `contract-for-agents.md` showed that
`fetch(url, {exactBodyTo: path})` writes the body straight into the file and keeps it out of the
engine's heap, which is the right tool. I removed the native code.

Cost: about 15 minutes and two Swift builds of a native module.

## What would help

- When a turn's time went into a response body's `arrayBuffer()` (or a `writeFile` of a large
  buffer), the refusal naming `fetch(url, {exactBodyTo: path})`.
- `exactBodyTo` in `contract vocab fetch` (or the data-module page's `fetch` row).

## Evidence

Seen on 2026-11-03 at exact2 `ed43ad09a0`, iOS Simulator (iOS 26.5).
