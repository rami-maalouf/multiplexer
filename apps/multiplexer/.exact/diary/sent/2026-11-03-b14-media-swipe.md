surfaces: ios
agent: Claude Opus 5.5
task: in a chat app's transcript, swipe right to reply on photos, videos, stickers and files as on a text bubble, and Copy for a held photo

### Rough
- A swipe on a photo opened the photo instead. The photo was a `button` (tap opens it, `contextmenu` holds it) inside a `box` with `swiperight`, as the voice row is built (where it works, because a drag there starts on the waveform, not on the play button). A drive with `--touch platform` and `tap photo-swipe-26 drag 90 0` opened the viewer. The cause is in the iOS host's source only (`AgentPanIOS.swift`: "a press below a node keeps its swipe and drag bindings from the touch (rule 3)"); `contract vocab swiperight` and the pitfalls page say nothing of it, and nothing warns. Workaround: the tap, the long press and the swipe on one node (a `SwipeReply` button with `press`, `contextmenu` and `swiperight`), and the photo, the video's poster, the sticker and the file bubble turned into components that only draw. About 15 minutes and three drives. What would have helped: a line in `contract vocab swiperight` ("a press inside it keeps the touch; put `press` on the swiped node"), or a compiler warning for a `press` inside a `swiperight` node.
- Copy for a photo: `contract vocab clipboard` answers "copying is the host command `copyText(text)`", so I wrote a native module op that put the picture on `UIPasteboard` (built and worked). Then `docs/contract-grammar.md` showed `@exact/clipboard` (a `ClipboardItem` of a PNG, from data code), which does it without native code. I removed the op. About 10 minutes and one Swift build. What would have helped: the vocab answer naming `@exact/clipboard` for an image.
- Under `--touch platform`, a tap on the chat list's `link` row missed ("the touch landed on node #542, not on node #45"), as finding 26 says; I opened the chat through the search's result buttons instead. About 3 minutes.

### Lean in
- `--touch platform` made a real drag: the refusal without it said exactly that ("a gesture only a real touch makes ... drive with --touch platform").
- `@exact/clipboard` with `storage.fs.compressImage(..., {type: 'image/png'})`: a JPEG photo became a PNG on the clipboard in five lines, and `state extensions.clipboard` showed the write (types, size, sha256) under the agent.
- `contract-use-missing` named both missing names and the exact `use` lines to write.

### Needed
- clipboard image write: provided (`@exact/clipboard`), hard to find (see Rough)
- swipe to reply on a tappable picture: provided, with one node for all three gestures (see Rough)

### Checkpoints
- Drives as a test user with `--touch platform`: a swipe right on a photo, a file, a video, a sticker and a large emoji each starts a reply with the right quote; a tap still opens a photo and a video; a long press still holds a photo and a sticker; Copy on a held photo writes a PNG (`state extensions.clipboard`).
- `verify ios`: clean (5 tests, check light and dark). `bun test`: 7 passed.
