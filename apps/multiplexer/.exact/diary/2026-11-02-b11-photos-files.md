surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: send photos and files from a chat's composer: a "+" button, a panel in the keyboard's place, the system pickers, a tray of picked items with a caption, upload progress on the message, and a file bubble that opens

### Rough
- The app's build folder (`target/`) was copied from another checkout of the same app (a second git worktree), so builds would be incremental. The first `agent ios` failed at once: `no matching rustc unit dep-info for unicode_ident; searched target directory <new checkout>/target; rebuild the stale Cargo unit or use a private target directory`. 561 of 562 `deps/*.d` files named the old checkout's target folder. Cargo itself found every unit fresh; only Exact's reader refused them. The message did not say which command rebuilds a unit, or that every unit was affected. I rewrote the old path in the cache's text files (1,421 files); the Rust half then passed, and Swift failed next: `precompiled file .../webarm-module-cache/.../SwiftShims-....pcm was compiled with module cache path '<old checkout>/...', but the path is currently '<new checkout>/...'`, then `missing required module 'SwiftShims'`. Removing `target/apple-swift` fixed it (a 1 min 39 s build). Cost about 8 minutes. What would have helped: the build noticing that its target folder moved (the recorded paths name another folder) and rebuilding or dropping the stale parts itself, or one message naming that cause and the folders to delete.

- A picked photo in a tray above the composer (`image <the picked app:/tmp/picked/ path>`, from `input type="file" accept="image/*"`) showed as an empty tile when the photo was a HEIC of 455 KB; a JPEG beside it showed. A 42 KB HEIC in the same drive showed too. Reading the host: `RasterMetadata.read` gives ImageIO the file's first 256 KB (`headerLimit`) as an incremental source, and when ImageIO answers no size from that part it fails the image (`RasterFailure.headerLimit`), with nothing in the drive's log. ImageIO seems to answer a HEIC's size only from the whole file, so an iPhone photo (HEIC, 1 to 3 MB), picked with `accept="image/*"` (which keeps HEIC), cannot be previewed. Cost about 10 minutes and two drives. What I did instead: an `accept` list without HEIC, so the picker converts it to a JPEG (D6). What would have helped: the header read falling back to the whole file for HEIC (the 64 MB limit still holds), or a log line naming why the picture failed.

- A drive answers a held picker with `type @<input id> <path>…`. One path with a space in it (`'/tmp/x/Trip plan.pdf'`, quoted) was split at the space: `type @pick-files: no such file /tmp/x/Trip`. Two paths with a newline between them had worked, so a newline after the single path worked too. The picker's code splits on newlines only when the text has one, else on any whitespace; no doc says so. Cost about 3 minutes and a drive. What would have helped: the step keeping a quoted value whole, or the doc line on held pickers naming the newline. (Later found: `agent-pitfalls.md` names `pick <id> "<path>"`, which keeps one quoted path whole; the error did not point to it, and `contract-for-agents.md`'s line on held requests shows only `type @`.)
- A file sent under the name of the picker's copy: an `input type="file"` delivers `Picked` with `name` "Trip plan.pdf" but `path` `app:/tmp/picked/1-3.pdf`. A library that names an upload after its path (as a chat library does) then sends "1-3.pdf". Nothing wrong in Exact, but the docs that describe `Picked` say "copies under app:/tmp/picked/" without saying the copy's name differs from `name`. Cost: one wrong send seen in a drive, and a link step (a hard link of the right name) in the native code, about 10 minutes. What would have helped: one sentence that the copy's file name is not the picked name.

- In a drive under `prefer prefers-color-scheme light`, I ran `check both` on one screen, then opened a picker and showed what it returned. The new nodes drew in the dark scheme in a light app: white text on a light grey tile, and the software keyboard dark. `check` then reported real-looking contrast failures on them (`1.3:1 (#ffffff on #dedee1)`). A new drive with the same steps and no `check both` before them drew them right, and `check` found nothing. Cost about 8 minutes, and a fix I first wrote for a bug that was not there. What would have helped: `check both` putting the scheme back for everything made after it, or its output saying which scheme the drive is in after it.

- `verify ios` flagged two fixed glyph sizes (`image ... font-size=20`) and said "a role (`font="-exact-title1"`) or a `rem` size ("1.25rem") scales". I wanted a size that scales but stops at a cap (a glyph in a fixed 44-point circle), so I wrote `font-size="min(1.25rem, 24px)"`. The build refused it: `[lower-attr-value] font-size="min(1.25rem, 24px)" is not a valid font-size: expected number`. Yet `font-size="1.25rem"` and `font-size="min(-exact-title3, 24px)"` both compile. I used the role form. Cost about 3 minutes and two test builds. What would have helped: `font-size` taking `rem` inside `min()` as `width` does, or the refusal naming the forms it takes.

### Lean in
- A second contract file (`attach.contract`) for the "+" button, the panel, the tray, the file bubble and the upload ring kept the main view's diff to a few lines, which matters when three branches merge into it.
- `input type="file"` with `showPicker(id)` gave both the system photo picker and the Files picker, with `Picked` copies the data module can read; under the agent the picker is held and `type @<id> <path>` answers it, so a drive picks real files with no UI scripting.
- `storage.fs.compressImage` with `maxDimension` and `maxBytes` gave both the photo to send and its thumbnail in two lines.
- `share(title=, files=)` opened a downloaded file in the share sheet with its own name, with no native code.
- `screenshot <png> over <ms> every <ms> window` filmed an upload's ring filling, frame by frame.
- `exactViewport().accessibilityTextSize` let a file bubble and a tray tile stack at the accessibility sizes, one prop each; `check` then reported no findings at the largest size.
- A sample chat app in exact2 with attachments showed the picker pattern in working code.
- `verify ios` named each literal colour, `sf/` symbol, fixed glyph size and plural slip with its file, line and fix; all 8 were cleared in one pass (theme tokens, icon tokens with an SVG each), and the next run was clean.

### Needed
- photo library picker: provided (`input type="file" accept=... multiple`, `showPicker`); rough for HEIC (see Rough)
- document picker (Files): provided (`input type="file"` with no `accept`)
- image resize and re-encode: provided (`storage.fs.compressImage`)
- open or share a file: provided (`share(files=)`)
- a custom view in the keyboard's place (an input view): not provided; the panel is drawn where the keyboard was, after `blur`
- an upload progress ring: built by hand (an SVG circle with `stroke-dasharray`)

### Checkpoints
- editing app.contract / attach.contract / app.ts: smooth
- iOS build: rough once (a target folder copied from another checkout, see Rough); then smooth for contract edits; about 30 to 40 s for a modules/apple Swift edit, as before
- driving the app (`exact.mjs agent`): smooth for pickers and films; rough for a path with a space and after `check both` (see Rough)
- images: rough for a HEIC over 256 KB (see Rough)
