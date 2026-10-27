surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: photo messages in a chat: a native module downloads each picture into the app's cache and the view shows it, sized by its aspect ratio, with a full-screen viewer that zooms out of the thumbnail

### Rough
- What an `image` may show was hard to find. `contract vocab image` printed "image: tag, Image (html); positional imageSource"; `bun exact.mjs docs image` printed the app.json recipe (`assets/`). The rule is one sentence in `docs/contract-for-agents.md`'s media section ("A media source is the string an `image` takes, `app:/data` files included"), found by grep. That a module's file in `context.cache` shows as `app:/cache/<name>` is not written anywhere; it worked. ~5 min. What would have helped: `contract vocab image` naming its sources, and one line in `docs/recipes/native-module.md` on handing the view a file the module wrote.

- The thumbnails download after the chat opens; the module then calls `context.changed`. A drive had no way to wait for them, so it used `"clock +2000 real"` (the finding that a drive cannot wait for a module's own work).

### Lean in
- `lower-colour-one-scheme` refused `background-color="black"` on the viewer and named the fix; leaving the colour unsaid gave the system background, as the platform's viewer has.
- `aspect-ratio` from a template (`${w} / ${h}`) kept each photo's shape before its picture arrived, so nothing jumped when it did.
- `navigationPresentation="fullscreen"` with `navigationSource` naming the thumbnail's `id` opened the viewer zooming out of the photo, the first time.

### Needed
- none

### Checkpoints
- editing app.contract / app.ts: smooth
- editing modules/apple Swift: rough (31 to 36 s a build)
- driving the app (`exact.mjs agent`): rough (a real-time wait for downloads)
