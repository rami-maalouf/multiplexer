surfaces: ios
agent: Claude Opus 5.5
task: a chat app's list whose content was wider than the screen: find the text wider than its box (real data, read only) and make it end in an ellipsis inside its row; also prove a chat's return from the background

### Rough
- `layout <list>` and each row's `scroll` read `scroll viewport 0,0 of 0,0`, even with a probe row made a horizontal scroll and a control text drawing 847 pt past its box: the scroll range does not show a text's spill. About 25 minutes.
- `check` named the spill ("its text is 60 pt wider than its box"), but only on screen: 31 `tap <list> drag 0 -480` + `check` pairs per scan, about 3 minutes each, three scans. A first scan missed the rows because the data changed between scans.
- `tap <list> into <key>` on a list that is not virtualized answered `tapped ... into={key}` and did not scroll, saying nothing. About 5 minutes.
- `clock until state <path> != ""` was refused (only `==`). About 2 minutes.
- An older view's data module, run on the newer build to measure the old layout, failed on a field the old shape did not know (`... answered outside its shape: field lastStatus`); stripping it in a throwaway copy worked.
- A chat's return from the background could not be driven with Exact's drive: used the bench drive (`home`), `simctl launch` and `simctl io recordVideo` (evidence added to the known finding).

### Lean in
- `verify` flagged `overflow-wrap="anywhere"` ("breaks inside words (Octo/ber)"), which led to `break-word`, the right value.
- `check`'s message names the node, its box and the spill in points: enough to find the row's data at once.

### Needed
- `check <scroller> --all`, or a text's laid-out width in `layout`.

### Checkpoints
- The spill: two link previews, 17 pt and 60 pt past their 310 pt box (76 + 310 + 60.875 = the list's 446.875 width seen before). After `break-word`: no spill in a scan of the whole list; dark, light and the largest text size checked on the real row.
- The return: same process before and after, new messages arrive with no spinner and no step back; `verify ios` clean.
