surfaces: ios
agent: Cursor Auto
task: stage GIFs photos and videos in the composer until Send

# Media waits for Send

## Rough

- Nothing new for Exact on this change. Staging a GIF reused the photo tray
  (`attachPhotos` / `Chosen`); the compiler accepted it on the first build.

## Lean in

- Photos already joined the tray and waited for Send; only KLIPY's tap sent at once.
  Matching that path for GIFs was a straight swap of `sendGif` for `stageGif` plus
  `attachPhotos`.

## Needed

- Nothing new.

## Checkpoints

- GIF pick → tray (caption, remove, add another) → Send posts one message.
- Photos picker also accepts videos; they join the tray as non-picture attachments.
- Simulator shots in `.exact/media-draft/`; build installed on the phone.
