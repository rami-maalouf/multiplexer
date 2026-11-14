surfaces: ios
agent: claude opus 5.5
task: open network links and member profiles in the network's own app

### Rough
- a box's `height` refused a text-style length (`min(-exact-title3, 24px)`, the same value its icon takes as `font-size`), and `contract build --json --errors-only` printed the one refusal seven times. the message pointed to `font-size`; `font-size` on the box plus `height="1.2em"` worked. about 2 minutes.
- a host-matching rule written as contract `fn`s (a link's host, a list of sites) could not get a unit test: authored tests have no expression step, and they start signed out, so no chat with a link is reachable. drives were the only check. known finding 86. about 4 minutes reading the test grammar.
- `test ios` again signed out the drives' kept session; the next drive met the sign-in screen and needed a new sign-in. known finding 132. about 2 minutes.

### Lean in
- a refused `symbol:icon.<name>` named `contract vocab symbol`, whose list had the exact role needed (`open-app`), so no icon file was drawn.
- drive journals name each `openURL` and each held in-app browser, which proved the before and after of a tap without a device.
- `tap` refusals name the inline link run to tap instead, and say when a target needs quoting.

### Needed
- a link to another app (a universal link only, falling back in the app): by hand; a host list chooses `openURL` over the in-app browser.

### Checkpoints
- reproduced: an Instagram reel link in a test chat opened the in-app browser (journal: browser held).
- fixed: the same tap journals `openURL https://www.instagram.com/reel/...`; a plain link still holds the in-app browser.
- member page: an "Open in <network>" button beside Message; light and dark screenshots with labels aligned (forced link, reverted); a Matrix member shows no button.
- a reel-shaped video (poster, caption, link) plays full screen in the app.
- 14 authored iOS tests, 55 bun tests, 2 focused MatrixCore live tests pass.
