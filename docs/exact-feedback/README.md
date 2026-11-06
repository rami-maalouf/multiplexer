# Exact feedback

This folder records each place where building Multiplexer with Exact was hard. Its
purpose: Rami and the Exact team can improve the framework. Read this page first.

| What | Where |
|---|---|
| Findings, one file each, in exact2's issue format | [`issues/`](issues/) |
| Raw notes, one file per task, in Exact's diary format | [`apps/multiplexer/.exact/diary/`](../../apps/multiplexer/.exact/diary/); entries already sent are in `sent/` |
| What was sent to the Exact team, and when | "Sent to the Exact team", below |
| The rule that every agent follows | `AGENTS.md`, "Exact feedback: always record it" |

The findings use no app name, server name or account name, so they can go to the
Exact team as they are.

## Findings

Findings 1 to 22 were rechecked against exact2 `cee509ac82` (2026-10-27); 23 to 27 were seen at `1bc4c36cb7` (2026-10-31), where 12 and 15 were seen again (their files have the evidence). On 2026-11-02, 28 was seen at `1bc4c36cb7` 29 at `ed43ad09a0`, and 33 and 34 at `d165f8959f`, with new evidence for 13, 26 and 27; at `ed43ad09a0`, 15 was seen again and 21 is fixed; 30 to 32 and 35 to 41 were seen at `ed43ad09a0`, 17 was seen again, and 13 and 30 have new evidence; 48 to 50 were seen at `ed43ad09a0`, with new evidence for 37; 51 to 56 on 2026-11-03, with new evidence for 13, 26, 27 and 44; 57 to 59 were found while fixing findings in pull requests (first numbered 51 to 53, which were taken); 60 to 63 on 2026-11-03, with new evidence for 4, 41 and 55; 64 to 68 on 2026-11-03, with new evidence for 13, 4, 27, 54 and the virtualized list's strip. 69 to 72 on 2026-11-03, with new evidence for 10 and 26; 73 to 76 on 2026-11-03, with new evidence for 2 and 60; 83 to 85 on 2026-11-03 (77 to 82 are B18 search's, with new evidence for 13 and 26), with new evidence for 61 and the zoom filming finding; 86 on 2026-11-03, with new evidence for the long-press scroll finding. 87 to 89 on 2026-11-03 at `ed43ad09a0`, with new evidence for 13 and 37. 97 to 101 on 2026-11-03 at `574720f370`, while fixing findings in pull requests, with new evidence for 42. 106 and 107 on 2026-11-03 at `ed43ad09a0`, from the transcript's loading line, with new evidence for 29. 108 to 110 on 2026-11-03 at `ed43ad09a0`, from Remind Me. 119 on 2026-11-03 at `ed43ad09a0`, from Merge Chats, with new evidence for 55. 120 on 2026-11-04 at `ed43ad09a0`, from the UI faults, with new evidence for 55 (its cause, and a local fix), 76 and 106. 90 and 91 on 2026-11-03, with new evidence for 26. 93 to 95 on 2026-11-03 (Send Later; 92 is the GIF task's), with new evidence for 26 and 61. 92 on 2026-11-03, with new evidence for 61. On 2026-11-03 (a jump count task), new evidence for 13 and 19. 102 to 105 on 2026-11-03 at `ed43ad09a0` (a camera), with new evidence for 37 and 46. 117 and 118 on 2026-11-03 at `ed43ad09a0` (push on the Simulator), with new evidence for 46.

Later-lane evidence (2026-11-04): communities and Requests, finding 122; New Space, findings 1, 2 and 52; preview checks, finding 40; verification exit status, finding 121.

| # | Finding | Cost | Severity | File |
|---|---|---|---|---|
| 1 | Each Swift edit compiles all of `modules/apple` again, including a vendor's 2 MB of bindings. Further evidence on 2026-11-04. | 31 to 42 s for each edit; latest native build 83.0 s (host arms 63.8 s) | P2 | [module-swift-recompiles-vendor-bindings](issues/20261027-module-swift-recompiles-vendor-bindings.md) |
| 2 | An authored test cannot read a secret, so `verify` never reaches the screens behind a sign-in. | A text-size bug that `verify` missed | P2 | [authored-tests-cannot-read-a-secret](issues/20261027-authored-tests-cannot-read-a-secret.md) |
| 3 | A native module can use only real files in `modules/apple`: no links, no local Swift package. | About 20 min, then a copy step after each edit | P3 | [module-swift-only-from-modules-apple](issues/20261027-module-swift-only-from-modules-apple.md) |
| 4 | A native module cannot keep a secret in Exact's store, so its Keychain items outlive a fresh drive. | A test device left signed in on the server | P3 | [native-module-has-no-secret-store](issues/20261027-native-module-has-no-secret-store.md) |
| 5 | The editor cannot resolve native module Swift, so every line shows an error. | No quick feedback while editing | P3 | [editor-cannot-resolve-module-swift](issues/20261027-editor-cannot-resolve-module-swift.md) |
| 6 | `state` prints the value that a password field is bound to. | A password can reach the agent's output | P3 | [agent-state-prints-a-password](issues/20261027-agent-state-prints-a-password.md) |
| 7 | A `role="status"` readout holding a `progress` is hidden from the iOS bar, with no warning. Fixed in PR #1358 (open). | About 5 min | P3 | [ios-bar-hides-a-status-readout-with-progress](issues/20261027-ios-bar-hides-a-status-readout-with-progress.md) |
| 8 | An app cannot say that it runs on iOS only. | Web tests fail | P3 | [an-app-cannot-say-it-runs-on-ios-only](issues/20261027-an-app-cannot-say-it-runs-on-ios-only.md) |
| 9 | The native-module recipe leaves out the module's folders, its Swift mode, how `clock data` treats `later`, and how to hand the view a file the module wrote. Partly fixed in PRs #1341 and #1359 (open). | About 20 min | P3 | [native-module-recipe-gaps](issues/20261027-native-module-recipe-gaps.md) |
| 10 | `contract vocab` names a tag or property but not its attributes or values. Partly fixed in PR #1359 (open). | About 5 min | P3 | [vocab-gives-no-attributes-or-values](issues/20261027-vocab-gives-no-attributes-or-values.md) |
| 11 | `prefer root-font-size` enlarges Exact's text but not native fields. Fixed in PR #1342 (open). | About 3 min | P3 | [prefer-root-font-size-leaves-native-text](issues/20261027-prefer-root-font-size-leaves-native-text.md) |
| 12 | The `chat-thread` recipe fails Exact's own checks as written: `overflow-wrap="anywhere"` (`verify ios`), and a composer field under 44 points (`check`). Fixed in PR #1323 (open). | About 7 min | P3 | [chat-thread-recipe-breaks-inside-words](issues/20261027-chat-thread-recipe-breaks-inside-words.md) |
| 13 | Eight agent messages could say what to do next. Partly fixed in PR #1338 (open). | 1 or 2 min each | P3 | [small-agent-drive-messages](issues/20261027-small-agent-drive-messages.md) |
| 14 | Withdrawn: "an app that uses exact2 by path cannot safely follow a rewritten `main`". The cost came from a one-time purge of exact2's git history, not from the framework or from building an app with it. | | | (file removed) |
| 15 | After `update`, `lock` reports "no changes" for a `Cargo.lock` that `update` rewrote. Fixed in PR #1347 (open). | About 2 min | P3 | [update-and-lock-disagree-about-cargo-lock](issues/20261027-update-and-lock-disagree-about-cargo-lock.md) |
| 16 | A drive cannot wait for work that a native module starts by itself or pushes after a mutation, so it needs a fixed real-time wait. | About 6 min, and slow drives | P3 | [a-drive-cannot-wait-for-a](issues/20261027-a-drive-cannot-wait-for-a.md) |
| 17 | `clock until state` and `expect state` take different path forms, and the refusal shows only the grammar. Fixed in PR #1339 (open). | About 3 min and a wasted drive | P3 | [clock-until-state-and-expect-state](issues/20261027-clock-until-state-and-expect-state.md) |
| 18 | A `compare` step empties the store for the whole drive, and nothing says so. Fixed in exact2 at `cee6cccb34`: the drive prints "starts empty, as a drive that compares with a reference does", and `--keep-storage` keeps the store. | About 5 min | P3 | [a-compare-step-empties-the-store](issues/20261027-a-compare-step-empties-the-store.md) |
| 19 | A transcript moved by one row when an update removed its first row above the view (seen once, not isolated). Not reproduced in a minimal app on 2026-11-03, so no PR. | About 10 min to measure | P3 | [a-transcript-moved-by-one-row](issues/20261027-a-transcript-moved-by-one-row.md) |
| 20 | A virtualized list has no place for a row outside its `for`, so a chat cannot show that it is loading older messages, or that it has reached the start. It has: a marker item put first by a `derive`; PR #1411 (open) documents it. | About 3 min, and a gap in the chat | P3 | [a-virtualized-list-has-no-place](issues/20261027-a-virtualized-list-has-no-place.md) |
| 21 | Closed: fixed in exact2 (`rem` inside `min()` compiles at `ed43ad09a0`). Was: a size could not both scale with the text and stop at a cap. | About 2 min, and a fixed-size picture | P3 | [rem-cannot-go-inside-min-so](issues/closed/20261027-rem-cannot-go-inside-min-so.md) |
| 22 | `ios --device` does not check the pinned toolchain's iPhone Rust target before building; it fails a minute in. Fixed in PR #1356 (open). | About 3 min | P3 | [ios-device-does-not-check-the](issues/20261028-ios-device-does-not-check-the.md) |
| 23 | `exact update` appends `/.exact/` to `.gitignore` on every run, so an app that keeps its diary in git loses new diary files. Fixed in PR #1344 (open). | About 10 min | P3 | [exact-update-re-adds-a-gitignore](issues/20261031-exact-update-re-adds-a-gitignore.md) |
| 24 | The theme recipe says `contract vocab -exact-label` answers a role; it does not, and no page lists the roles. Partly fixed in PR #1342 (open). | About 10 min | P3 | [the-theme-recipe-says-contract-vocab](issues/20261031-the-theme-recipe-says-contract-vocab.md) |
| 25 | `check` misses the accent fill under a bubble that a sibling paints, so the sample chat app's tailed bubble fails contrast. | About 15 min | P3 | [check-misses-the-accent-fill-under](issues/20261031-check-misses-the-accent-fill-under.md) |
| 26 | A drive cannot fire `swiperight`, and under a real touch a tap on a `link` row misses. | About 10 min | P3 | [a-drive-cannot-fire-swiperight-and](issues/20261031-a-drive-cannot-fire-swiperight-and.md) |
| 27 | A long-press menu has no row of reactions, so a chat app draws its message menu by hand. | About 40 lines | P3 | [a-long-press-menu-has-no](issues/20261031-a-long-press-menu-has-no.md) |
| 28 | Swipe to reply has no recipe: the `transition` gives the spring back (agent-pitfalls says it gives the follow), and `swipeIndicator` and the host's threshold haptic are undocumented. Fixed in PR #1323 (open). | A wrong conclusion in one session, about 40 min in the next | P3 | [swipe-to-reply-has-no-recipe](issues/20261102-swipe-to-reply-has-no-recipe.md) |
| 29 | Corrected: `--timing platform` gives UIKit's real timing (the iOS driving recipe), but `screenshot over` refuses under it, so filming a UIKit transition still needs a Simulator recording (known in exact2's `QUEUE.md`). Was: a drive cannot film a navigation's zoom. | About 10 min | P3 | [a-drive-cannot-film-a-navigation](issues/20261102-a-drive-cannot-film-a-navigation.md) |
| 30 | A `target/` folder built at another path (copied from another checkout) fails the build with `no matching rustc unit dep-info`, and the message does not say to delete it. Fixed in PR #1355 (open). | About 10 min, then a full build | P3 | [a-target-folder-built-at-another](issues/20261102-a-target-folder-built-at-another.md) |
| 31 | A plain list's separator starts at the initials inside a row's round picture, so the lines jump from row to row (known in exact2's `QUEUE.md`; this adds evidence). | About 15 min | P3 | [a-list-row-s-separator-starts](issues/20261102-a-list-row-s-separator-starts.md) |
| 32 | A labelled image inside a `link` row is left out of the row's VoiceOver label, unlike the web. Fixed in PR #1407 (open). | About 10 min | P3 | [a-labelled-image-inside-a-link](issues/20261102-a-labelled-image-inside-a-link.md) |
| 33 | `verify` says "tests: did not compile" when it could not pick a simulator. Fixed in PR #1325 (open). | About 3 min | P3 | [verify-says-the-tests-did-not](issues/20261102-verify-says-the-tests-did-not.md) |
| 34 | `verify`'s largest-text pass keeps no screenshots, so a finding there cannot be seen. Fixed in PR #1348 (open). | About 25 min, not isolated | P3 | [verify-s-largest-text-pass-keeps](issues/20261102-verify-s-largest-text-pass-keeps.md) |
| 35 | A floating bottom bar over a large-title list gets no scroll edge effect, and a route has no bottom toolbar. | About 25 min | P3 | [a-floating-bottom-bar-gets-no-edge-effect](issues/20261102-a-floating-bottom-bar-gets-no-edge-effect.md) |
| 36 | `match` on a string is refused as "expected `some`, found a string". Fixed in PR #1349 (open). | About 3 min | P3 | [match-on-a-string-is-refused](issues/20261102-match-on-a-string-is-refused.md) |
| 37 | A native button's symbol: the hint says "sized by font-size", `font-size` on the button is ignored without a warning, and an image's `font-size` cannot grow to a cap. Partly fixed in PRs #1343 and #1349 (open). | About 16 min | P3 | [a-native-buttons-symbol-size](issues/20261102-a-native-buttons-symbol-size.md) |
| 38 | A picked HEIC photo over 256 KB shows as an empty image, with no log line. Fixed in PR #1337 (open). | About 10 min and two drives | P2 | [a-picked-heic-photo-over-256](issues/20261102-a-picked-heic-photo-over-256.md) |
| 39 | The docs do not say that a picked file's copy has another name than `Picked.name`. Fixed in PR #1342 (open). | One wrong send, about 10 min | P3 | [the-docs-do-not-say-that](issues/20261102-the-docs-do-not-say-that.md) |
| 40 | After `check both`, nodes made later in the drive drew in the other color scheme (seen once). | About 8 min and a wrong fix | P3 | [after-check-both-nodes-made-later](issues/20261102-after-check-both-nodes-made-later.md) |
| 41 | `font-size` still refuses `rem` inside `min()`, which `width` now takes (follows closed finding 21). Partly fixed in PR #1349 (open): the refusal names the forms. | About 3 min | P3 | [font-size-still-refuses-rem-inside](issues/20261102-font-size-still-refuses-rem-inside.md) |
| 42 | Running a framework script's tests with a newer Bun fails: `ensureBun` drops the `test` verb. Fixed in PR #1345 (open). | About 3 min | P3 | [running-a-framework-script-s-tests](issues/20261102-running-a-framework-script-s-tests.md) |
| 43 | Parallel sessions on one machine share the default Simulator: an `ios --run` replaced another session's app in the middle of its drive. Fixed in PR #1329 (open). | About 15 min | P3 | [parallel-sessions-on-one-machine-share](issues/20261102-parallel-sessions-on-one-machine-share.md) |
| 44 | A virtualized list draws rows past its frame, under the bar that follows it, and refuses `overflow`. | About 25 min | P3 | [a-virtualized-list-draws-rows-past](issues/20261102-a-virtualized-list-draws-rows-past.md) |
| 45 | No keyboard fact: a chat cannot keep a message in view as the keyboard comes up. | About 15 min | P3 | [no-keyboard-fact-a-chat-cannot](issues/20261102-no-keyboard-fact-a-chat-cannot.md) |
| 46 | An app checkout at another folder depth cannot build: `EXACT2` does not cover the app's Cargo paths. Partly fixed in PR #1346 (open). | About 10 min, four builds | P3 | [an-app-checkout-at-another-depth](issues/20261102-an-app-checkout-at-another-depth.md) |
| 47 | A real-touch tap at a point does not scroll its target into view, and a tap that opened nothing still says "tapped". Partly fixed in PR #1340 (open). | About 8 min, five drives | P3 | [a-real-touch-tap-at-a](issues/20261102-a-real-touch-tap-at-a.md) |
| 48 | `check` measures a half-height sheet's rows at their drawn size (x0.96) and does not say why. Partly fixed in PR #1368 (open). | About 3 min | P3 | [check-measures-a-half-height-sheet](issues/20261102-check-measures-a-half-height-sheet.md) |
| 49 | A plain list's first row has a top separator that the app cannot hide. | About 6 min | P3 | [a-plain-list-s-first-row](issues/20261102-a-plain-list-s-first-row.md) |
| 50 | `scrollIntoView` cannot open a collapsed large title again. | About 10 min | P3 | [scrollintoview-cannot-open-a-collapsed-large](issues/20261102-scrollintoview-cannot-open-a-collapsed-large.md) |
| 51 | A symbol inside a text with no width or height draws nothing, with no warning. | About 20 min | P3 | [a-symbol-inside-a-text-with](issues/20261103-a-symbol-inside-a-text-with.md) |
| 52 | A drive cannot reach a long-press menu row below the fold at the largest text size. | About 6 min | P3 | [a-drive-cannot-reach-a-long](issues/20261103-a-drive-cannot-reach-a-long.md) |
| 53 | A screen with its own top bar has no documented way to clear the status bar (a zero-height box works). | About 10 min | P3 | [a-screen-with-its-own-top](issues/20261103-a-screen-with-its-own-top.md) |
| 54 | `check` calls a view covered when the bar over it only lets touches through (`pointer-events: none`). | About 5 min | P3 | [check-calls-a-view-covered-when](issues/20261103-check-calls-a-view-covered-when.md) |
| 55 | `check` flags rows that scroll under an app-drawn floating bar as overlaps. | About 5 min each time | P3 | [check-flags-rows-that-scroll-under](issues/20261103-check-flags-rows-that-scroll-under.md) |
| 56 | A drive cannot start a drag at a point, so it cannot make an edge swipe. It can: `tap <root> drag 320 0 from 2 <y>`; PR #1406 (open) makes the refusal name it. | About 3 min | P3 | [a-drive-cannot-start-a-drag](issues/20261103-a-drive-cannot-start-a-drag.md) |
| 57 | The host tests refuse to run without the Metal toolchain, which a build does without. | About 10 min | P3 | [the-host-tests-refuse-to-run](issues/20261103-the-host-tests-refuse-to-run.md) |
| 58 | The host tests cannot run one test class: `--test` runs all 318 classes. | About 15 min | P3 | [the-host-tests-cannot-run-one](issues/20261103-the-host-tests-cannot-run-one.md) |
| 59 | `caps` counts one more line than `wc -l`. Fixed in PR #1365 (open). | About 3 min | P3 | [caps-counts-one-more-line-than](issues/20261103-caps-counts-one-more-line-than.md) |
| 60 | iOS adds a hyphen inside a link's address under `break-word`, and an inline run's `hyphens` is dropped. | About 15 min | P3 | [ios-hyphenates-a-link-inside-a](issues/20261103-ios-hyphenates-a-link-inside-a.md) |
| 61 | A members file's rules do not say whether it may also hold components, and `contract vocab` does not know `members`. Fixed in PR #1364 (open). | About 5 min | P3 | [a-members-file-s-rules-leave](issues/20261103-a-members-file-s-rules-leave.md) |
| 62 | A drive's view of a video: `state media` is not in the agent's help, AVKit's controls show only under a real touch, and a video under the agent never takes the audio session. Fixed in PR #1366 (open). | About 10 min | P3 | [a-drive-cannot-see-a-video-s](issues/20261103-a-drive-cannot-see-a-video-s.md) |
| 63 | `formatDay` has no style for a chat's day label. | About 5 min | P3 | [formatday-has-no-style-for](issues/20261103-formatday-has-no-style-for.md) |
| 64 | A search field in a sheet's content draws its magnifier over its text at the accessibility sizes. | About 15 min | P3 | [a-search-field-in-a-sheet](issues/20261103-a-search-field-in-a-sheet.md) |
| 65 | A sheet's bar search field hides the bar and its Send while searching, and the search card does not say so. Fixed in PR #1367 (open). | About 10 min | P3 | [a-sheet-s-bar-search-field](issues/20261103-a-sheet-s-bar-search-field.md) |
| 66 | The edit-sheet recipe nests a sheet's header as `lower-header-nested` warns against. Fixed in PR #1361 (open). | About 5 min | P3 | [the-edit-sheet-recipe-nests-a](issues/20261103-the-edit-sheet-recipe-nests-a.md) |
| 67 | The theme recipe shows an SF-only icon token, which the build refuses. Fixed in PR #1362 (open). | About 2 min | P3 | [the-theme-recipe-shows-an-sf](issues/20261103-the-theme-recipe-shows-an-sf.md) |
| 68 | A drag on a virtualized list in a half-height sheet aims under the row after the list. | About 6 min | P3 | [a-drag-on-a-virtualized-list](issues/20261103-a-drag-on-a-virtualized-list.md) |
| 69 | A list of plain numbers warns `lower-key-position` for its only key. | About 12 min | P3 | [a-list-of-plain-numbers-warns](issues/20261103-a-list-of-plain-numbers-warns.md) |
| 70 | `audio-waveform`'s `tint` takes only a hex colour. | About 3 min | P3 | [audio-waveform-s-tint-takes-only](issues/20261103-audio-waveform-s-tint-takes-only.md) |
| 71 | `@exact/recording` cannot write Ogg Opus, the voice note format of chat networks. | About 45 min | P3 | [exact-recording-cannot-write-ogg-opus](issues/20261103-exact-recording-cannot-write-ogg-opus.md) |
| 72 | The permissions recipe does not say that a refused request runs no `then`. Fixed in PR #1363 (open). | About 10 min | P3 | [the-permissions-recipe-does-not-say](issues/20261103-the-permissions-recipe-does-not-say.md) |
| 73 | On iOS a route's title cannot open a menu, and the ways that look like they should fail quietly. | About 30 min | P2 | [a-large-title-cannot-open-a-menu](issues/20261103-a-large-title-cannot-open-a-menu.md) |
| 74 | A disabled menu row with no press is dropped from the iOS menu. | About 5 min | P3 | [a-disabled-menu-row-without-a-press](issues/20261103-a-disabled-menu-row-without-a-press.md) |
| 75 | A test's `reload` on iOS comes back at the first screen, not where `at` opened it. | About 3 min | P3 | [a-test-s-reload-forgets-its](issues/20261103-a-test-s-reload-forgets-its.md) |
| 76 | A large title comes back inline when a route with no bar turns into one with a large title. Fixed in PR #1410 (open). | About 8 min | P3 | [a-large-title-comes-back-inline](issues/20261103-a-large-title-comes-back-inline.md) |
| 77 | A comment line before an if block's first line ends the block. | About 2 min | P3 | [a-comment-line-ends-an-if-block](issues/20261103-a-comment-line-ends-an-if-block.md) |
| 78 | A header search field has no close event, and a drive cannot press it or its close button. | About 20 min | P3 | [a-header-search-field-has-no-close-event](issues/20261103-a-header-search-field-has-no-close-event.md) |
| 79 | A list cell's row brings a gap and padding from its tag, which the list docs do not say. | About 5 min | P3 | [a-list-cells-row-brings-gap-and-padding](issues/20261103-a-list-cells-row-brings-gap-and-padding.md) |
| 80 | A data module answer refused for its 100 ms turn shows as a stale page; only logs name it. | About 10 min | P3 | [a-refused-data-module-answer-shows-stale](issues/20261103-a-refused-data-module-answer-shows-stale.md) |
| 81 | A search field in content gets the web address keyboard. | About 2 min | P3 | [a-search-field-gets-the-web-address-keyboard](issues/20261103-a-search-field-gets-the-web-address-keyboard.md) |
| 82 | `display` on a list turns its cells into a flex row, with no warning. | About 5 min | P3 | [display-on-a-list-turns-its-cells](issues/20261103-display-on-a-list-turns-its-cells.md) |
| 83 | The zoom transition (`navigationSource`) has no doc an app can read. | About 10 min | P3 | [navigation-source-has-no-doc](issues/20261103-navigation-source-has-no-doc.md) |
| 84 | A route cannot say "a bar with buttons and no title" without an empty heading. | About 3 min | P3 | [a-bar-with-buttons-and-no](issues/20261103-a-bar-with-buttons-and-no.md) |
| 85 | `path()` takes only a literal route name, so a choice of two routes needs two pushes. | About 1 min | P3 | [path-needs-a-literal-route-name](issues/20261103-path-needs-a-literal-route-name.md) |
| 86 | A contract `fn` has no unit test, so a rule lives in TypeScript and the contract repeats it. | About 6 min | P3 | [a-contract-fn-has-no-unit](issues/20261103-a-contract-fn-has-no-unit.md) |
| 87 | `press=` cannot take a choice of two actions, so one button that changes its action is two buttons. | About 1 min | P3 | [press-cannot-take-a-choice-of](issues/20261103-press-cannot-take-a-choice-of.md) |
| 88 | An empty list `[]` passed to a source cannot be typed, so an app adds a state that is only an empty list. | About 2 min | P3 | [an-empty-list-passed-to-a](issues/20261103-an-empty-list-passed-to-a.md) |
| 89 | A `resource` declaration cannot wrap onto a second line, and its refusal does not say so (a `derive`'s does). | About 1 min | P3 | [a-resource-declaration-cannot-wrap-onto](issues/20261103-a-resource-declaration-cannot-wrap-onto.md) |
| 90 | A `press` inside a `swiperight` node keeps the touch, so a tappable picture cannot be swiped, and no doc or warning says so. | About 15 min | P3 | [a-press-inside-a-swipe-node](issues/20261103-a-press-inside-a-swipe-node.md) |
| 91 | `contract vocab clipboard` says copying is `copyText` and does not name `@exact/clipboard` for an image. | About 10 min | P3 | [contract-vocab-clipboard-does-not-name](issues/20261103-contract-vocab-clipboard-does-not-name.md) |
| 92 | The data module's turn budget refusal suggests `scheduler.yield()` for a large download, and does not name `fetch(url, {exactBodyTo})`. | About 15 min | P3 | [the-turn-budget-refusal-does-not](issues/20261103-the-turn-budget-refusal-does-not.md) |
| 93 | `contract vocab` does not know an input's `type` values, so `datetime-local` (the date and time picker) reads as missing. | About 4 min | P3 | [contract-vocab-does-not-know-an](issues/20261103-contract-vocab-does-not-know-an.md) |
| 94 | A drive without real touches draws a menu as bare rows, without the system's menu, even in a window screenshot. | About 12 min | P3 | [a-drive-without-real-touches-draws](issues/20261103-a-drive-without-real-touches-draws.md) |
| 95 | A popover menu inside a list section draws as the section's cells, with no warning. | About 5 min | P3 | [a-popover-menu-inside-a-list](issues/20261103-a-popover-menu-inside-a-list.md) |
| 96 | A drive cannot wait on a list item found by its key: `clock until state` takes one path and `==`, so waits by index or count mislead when the list changes. | About 15 min and four drives | P3 | [a-drive-cannot-wait-on-a](issues/20261103-a-drive-cannot-wait-on-a.md) |
| 97 | The host tests print a failing test's name but not its assertion; the message is in one of two result bundles. | About 10 min | P3 | [the-host-tests-print-a-failing](issues/20261103-the-host-tests-print-a-failing.md) |
| 98 | A host test that needs a window scene runs hosted only when it says `missing("scene")`, which no doc says. | About 5 min | P3 | [a-host-test-that-needs-a](issues/20261103-a-host-test-that-needs-a.md) |
| 99 | Exact's own host tests fail on `origin/main` on an iOS 26.5 simulator, and one Mac test on a Canadian English Mac. | About 20 min | P3 | [exact-s-own-host-tests-fail](issues/20261103-exact-s-own-host-tests-fail.md) |
| 100 | An edge swipe that starts over a `pan` handler goes to the pan, not back; a `swiperight` waits for it. | About 5 min | P3 | [an-edge-swipe-that-starts-over](issues/20261103-an-edge-swipe-that-starts-over.md) |
| 101 | The host tests check for the Metal toolchain only after the Rust build. | About 2 min | P3 | [the-host-tests-check-for-the](issues/20261103-the-host-tests-check-for-the.md) |
| 102 | The camera has no recipe (open, view, shutter, stop, a drive's camera), `getPhotoCapabilities` is refused before a track exists, and nothing records a video. | About 15 min | P3 | [the-camera-has-no-recipe-and](issues/20261103-the-camera-has-no-recipe-and.md) |
| 103 | A compiler-supplied shape such as `Picked` cannot be built, and `contract vocab` does not know it. | About 15 min | P3 | [a-compiler-supplied-shape-such-as](issues/20261103-a-compiler-supplied-shape-such-as.md) |
| 104 | An action that sets a mutation to `none` and then sends it sends nothing, with no warning. | About 10 min and three drives | P3 | [clearing-a-mutation-and-sending-it](issues/20261103-clearing-a-mutation-and-sending-it.md) |
| 105 | A `header` in a route forced dark becomes the iOS bar, which draws its title in the light scheme's ink, and `check` does not see it. | About 10 min and four drives | P3 | [a-header-in-a-route-forced](issues/20261103-a-header-in-a-route-forced.md) |
| 106 | A git worktree of an app away from the folder next to the framework cannot build: `exact.mjs` and the framework packages in `package.json` use relative paths. | About 5 min | P3 | [a-worktree-of-an-app-away](issues/20261103-a-worktree-of-an-app-away.md) |
| 107 | A virtualized list asks `reachstart` once while its top stays in reach, so a request the app held back is never made again; no doc says so. | About 15 min | P3 | [a-virtualized-list-asks-reachstart-once](issues/20261103-a-virtualized-list-asks-reachstart-once.md) |
| 108 | Adding a package to an app has no app verb (`bun exact.mjs add`), and the framework's `add` writes an absolute `file:` path. | About 4 min | P3 | [adding-a-package-to-an-app](issues/20261103-adding-a-package-to-an-app.md) |
| 109 | An action in a members file the component does not name is reported as missing, with no word of the file. | About 2 min | P3 | [an-action-in-a-members-file](issues/20261103-an-action-in-a-members-file.md) |
| 110 | A drive cannot tap a row of an open menu that runs past the screen ("scroll it into view first"). | About 5 min | P3 | [a-drive-cannot-tap-a-row](issues/20261103-a-drive-cannot-tap-a-row.md) |
| 111 | A page opened from a sheet with `go` stays in the sheet, and a chat opened from it opens inside the half-height sheet too, with no warning. | About 5 min | P3 | [a-page-opened-from-a-sheet](issues/20261103-a-page-opened-from-a-sheet.md) |
| 112 | A data source's answer refused for its shape shows only in `logs`; a drive's `state` shows the old value with no word. | About 3 min | P3 | [a-refused-resource-answer-shows-only](issues/20261103-a-refused-resource-answer-shows-only.md) |
| 113 | A large title shows inline over a list with rows and large over an empty state, on the same page (not isolated). | About 3 min | P3 | [a-large-title-shows-inline-over](issues/20261103-a-large-title-shows-inline-over.md) |
| 114 | A plain list button sizes to its content instead of its cell, overflowing at large text sizes. | About 5 min | P3 | [a-plain-list-button-sizes-to](issues/20261103-a-plain-list-button-sizes-to.md) |
| 115 | A members name collision does not name the file declaring the state. | About 3 min | P3 | [a-members-name-collision-does-not](issues/20261103-a-members-name-collision-does-not.md) |
| 116 | The local run log retains a password argument that terminal output masks. | Found in under a minute | P1 | [the-local-run-log-retains-a](issues/20261103-the-local-run-log-retains-a.md) |
| 117 | An app cannot receive remote push: no token callback or source, no `aps-environment` for an app, and the archive check refuses `registerForRemoteNotifications`. | About 30 min, a run-time workaround, and no TestFlight | P2 | [an-app-cannot-receive-remote-push](issues/20261103-an-app-cannot-receive-remote-push.md) |
| 118 | An app cannot add its own app extension (a notification service extension) or declare an App Group, a Keychain group or `aps-environment`; on the Simulator the entitlements section has no room to grow. | About 90 min, and a script after every build | P2 | [an-app-cannot-add-its-own](issues/20261103-an-app-cannot-add-its-own.md) |
| 119 | A `derive` whose expression goes on to a second line is refused ("expected a section, found an indented block") with no word of the one-line rule. | About 2 min | P3 | [a-derive-s-expression-cannot-go](issues/20261104-a-derive-s-expression-cannot-go.md) |
| 120 | Content placed inside a `glassGroup` row took the glass away from its round glass buttons; no doc says what a glass group does with a child that is not glass. | About 5 min | P3 | [content-placed-inside-a-glass-group](issues/20261104-content-placed-inside-a-glass-group.md) |

| 121 | `verify ios` exits zero while its final report says there are problems. | About 3 min | P3 | [verify-ios-exits-zero](issues/20261104-verify-ios-exits-zero-while-its.md) |
| 122 | A drive says "the app hung up (exit code 0)" when the app crashed; the crash report shows only in the next drive's `logs`. | About 10 min and three drives | P3 | [a-drive-says-the-app-hung](issues/20261103-a-drive-says-the-app-hung.md) |

| 123 | A view-local `let` is reported as an unknown tag, followed by unknown-name errors at its uses. | About 2 min | P3 | [view-local-let](issues/20261104-view-local-let-reports-an-unknown.md) |
| 124 | A horizontal drag inside a full-width list link activates it on release, starting a navigation push. | Native controls and isolated host regression investigation | P2 | [horizontal-row-drag-activates-link](issues/20261104-horizontal-row-drag-activates-link.md) |
| 125 | A reactive navigation-root accent updates descendants but leaves a prominent native header blue. | Native visual mismatch and isolated regression investigation | P2 | [reparented-root-window-tint](issues/20261104-reparented-root-window-tint.md) |
| 126 | A physical-device release cannot qualify a target-only Swift package module roster. | About 282 s failed release plus 183 s development build | P2 | [device-release-roster-rejects-swift-package](issues/20261105-device-release-roster-rejects-swift-package.md) |
| 127 | Which swipe action a full swipe performs (the first id of `swipeTrailing`) is not documented; only the iOS host says it. | About 5 min | P3 | [which-swipe-action-a-full-swipe](issues/20261106-which-swipe-action-a-full-swipe.md) |
| 128 | Under real touches a drive cannot tap a native swipe action by its id, and `drag ... from x y` counts from content that moves while the row is open. | About 10 min | P3 | [a-drive-cannot-tap-a-native](issues/20261106-a-drive-cannot-tap-a-native.md) |
| 129 | A swipe row in a plain list loses the cell's 16-point margin, with no warning: its content needs its own padding. | About 20 min, one regression | P3 | [a-swipe-row-in-a-plain](issues/20261106-a-swipe-row-in-a-plain.md) |
| 130 | A swiped row's line runs from the cell's margin after it closes; fixed locally in the integration checkout (`cc75ef11d0`). | About 15 min | P3 | [a-swiped-row-s-line-runs](issues/20261106-a-swiped-row-s-line-runs.md) |
| 131 | A drive cannot cross the app leaving the foreground and coming back: no Home, app switcher or lock op, and every op fails while the app is away. | About 30 min | P3 | [a-drive-cannot-cross-a-return](issues/20261106-a-drive-cannot-cross-a-return.md) |

## What worked well

- Compiler errors name the fix (`lower-grouped-list`, `lower-empty-state-in-list`, symbol aliases).
- `clock data` waits for slow native replies, so tests and drives need no waits.
- Drives mask password fields in terminal output, and the command log keeps no arguments. The separate local run log needs the same masking (finding 116).
- A `list` with no `appearance` looks like the Messages app with no extra code.
- `formatDay(…, "list")` and `"day-time"` give a chat list's and a transcript's times.
- `modules/apple/*.xcframework` links a vendor's static library with no linker flags.
- `verify ios` rebuilds on its own after exact2 moves.

## What counts as a finding

Only Exact: its compiler, runtime, hosts, tools (`exact.mjs`, the agent, `verify`), docs
and recipes, and the process of building an app with them. The test: the cost came from
Exact, and a change to Exact would remove it.

Not a finding: a cost that came from somewhere else, such as Xcode, the Simulator, a
third-party library, a server, the network, git or the editor, even when it slowed the
task down. Record that in the task's notes (`tasks/todo.md`), not here.

## How to add a finding

1. When Exact costs you time, write it in the task's diary entry at once:
   `apps/multiplexer/.exact/diary/<YYYY-MM-DD>-<topic>.md` (format: `<exact2>/docs/diary.md`).
2. At the end of the task, search exact2's `issues/`, `issues/closed/` and `QUEUE.md`
   for the same problem. Also search the files here.
3. For a new problem, add an issue file here. Run this from this folder:
   `bun <exact2>/scripts/issue.mjs new "<title>" --systems "<a, b>" --severity P3 --author "Claude (Opus 5.5), from Rami Maalouf's chat app friction log (an app outside exact2)"`.
   Then write what happened, what would help, and where you saw it (the exact2 commit).
   For a known problem, add your evidence to its file.
4. Run `bun <exact2>/scripts/issue.mjs check` from this folder.
5. Add a row to the table above.
6. Keep each file generic: no app name, product purpose, server name, account name or secret.

If a new diary file does not show in `git status`, check `apps/multiplexer/.gitignore`:
it must keep `!/.exact/diary/`.

## Sent to the Exact team

Findings go to the team through Exact's private feedback tool. Run it from
`apps/multiplexer/`: `bun exact.mjs feedback preview` shows what would go, and
`bun exact.mjs feedback send` sends it. The tool sends only the entries at the top of
`.exact/diary/` and the new command-log lines. It then moves those entries into
`.exact/diary/sent/`, so commit that move.

| Date | Receipt | What | Sent by |
|---|---|---|---|
| 2026-10-27 | `4c8a0a07-60a8-466e-ae9a-bef9a0b29f82` | 4 diary entries (findings 1 to 15, in their Rough sections) and 77 command-log lines | Rami |
| 2026-10-27 | `ac63ff5c-08e3-461b-ae7f-5f1598b2125b` | Findings 1 to 15 as issue files, rechecked at exact2 `cee509ac82`, in the entry `2026-10-27-findings-for-the-team.md` | Claude, at Rami's request |
| 2026-10-27 | `cea3ed9a-11b2-4359-9849-7cab26e44f59` | 2 diary entries (findings 16 to 19, and new evidence for finding 4) and 20 command-log lines | Claude, with Rami's yes |
| 2026-10-27 | `a3326479-5a74-4d5f-8ac3-1351e418d588` | 3 diary entries (finding 20, and new evidence for findings 9, 12 and 16) and 39 command-log lines | Claude, with Rami's yes |
| 2026-11-02 | `f63c011a-dedb-4c1e-ae6b-4bee50181ae4` | 7 diary entries (findings 21 to 29, 33 and 34, and new evidence for findings 13 and 15; from the B1 and inbox entries, findings 30 to 32 and 35 to 37, and new evidence for findings 13 and 17) and 287 command-log lines | Claude, with Rami's yes |
| 2026-11-03 | `623dd86e-723a-4d6d-a5e1-d671e965d0d9` | 17 diary entries (the tasks of 2026-11-02 and 2026-11-03, B19 included; the app's README not attached) and 63 command-log lines | Claude, with Rami's yes |
| 2026-11-03 | `c0048b5e-44e2-40f5-aae3-63299084a8f0` | 2 diary entries (swipe to reply on media and Copy for a photo; Send Later: findings 90, 91 and 93 to 95) and 1 command-log line | Claude, with Rami's yes |
| 2026-11-03 | `1a0285c9-b1bf-4f21-a7f9-69a05a6cfc20` | 1 diary entry (GIFs: finding 92, new evidence for 61) and 18 command-log lines | Claude, with Rami's yes |

The first two sends include finding 14, which was withdrawn after they were sent.

To take a send back: `bun exact.mjs feedback delete <receipt>`.

To send a new finding: write it as an issue file here and in the task's diary entry, add
its row above, then send. Each send needs Rami's yes.

## Pull requests to exact2

Rami prefers a pull request to sending feedback (2026-11-02): when a finding is a problem
in Exact's docs or recipes that we can fix, fix it in a pull request to exact2
(`ccheever/exact2`; `ccheever/exact47` redirects there). Send feedback only for problems
that are hard to fix ourselves or need the Exact team's view first. Rami's GitHub account
can only read exact2, so a pull request comes from the fork `rami-maalouf/exact2`. Work in
a separate exact2 worktree at `origin/main`, never in the checkout the app uses. exact2's
own rules bind there (`AGENTS.md`, `rules/RULES.md`): its "Writing" section, the six checks,
and a 3,072-byte cap on each recipe (`bun scripts/caps.mjs`).

| Date | Pull request | Findings | State |
|---|---|---|---|
| 2026-11-02 | [#1323](https://github.com/ccheever/exact2/pull/1323): the chat-thread recipe passes `check`, and swipe to reply has a section in `contract-for-agents.md` | 12, 28 | Open |
| 2026-11-02 | [#1325](https://github.com/ccheever/exact2/pull/1325): `verify` says the tests could not run, not that they did not compile | 33 | Open |
| 2026-11-02 | [#1326](https://github.com/ccheever/exact2/pull/1326): a git worktree of an app can take another worktree's simulator (a pitfall) | 43 | Open |
| 2026-11-02 | [#1327](https://github.com/ccheever/exact2/pull/1327): a bar under a virtualized list needs a background, or rows show through it (a pitfall) | 44 | Open |
| 2026-11-02 | [#1329](https://github.com/ccheever/exact2/pull/1329): `exact.mjs ios` waits for a drive of the app on its simulator | 43 | Open |
| 2026-11-02 | [#1337](https://github.com/ccheever/exact2/pull/1337): a HEIC larger than 256 KiB is sized from its `meta` box, not shown empty | 38 | Open |
| 2026-11-02 | [#1338](https://github.com/ccheever/exact2/pull/1338): five agent refusals name the step to write | 13 | Open |
| 2026-11-02 | [#1339](https://github.com/ccheever/exact2/pull/1339): `clock until state` takes the path `expect state` takes | 17 | Open |
| 2026-11-02 | [#1340](https://github.com/ccheever/exact2/pull/1340): a tap at a point scrolls its view in before it refuses the point | 47 | Open |
| 2026-11-02 | [#1341](https://github.com/ccheever/exact2/pull/1341): the native-module recipe names a module's folders, its secrets and its Swift mode | 9 | Open |
| 2026-11-02 | [#1342](https://github.com/ccheever/exact2/pull/1342): three guide lines that sent an agent the wrong way | 11, 24, 39 | Open |
| 2026-11-02 | [#1343](https://github.com/ccheever/exact2/pull/1343): `verify` names a role with a cap for a text size that cannot grow | 37 | Open |
| 2026-11-02 | [#1344](https://github.com/ccheever/exact2/pull/1344): `exact update` keeps an app's `/.exact/*` diary rule | 23 | Open |
| 2026-11-02 | [#1345](https://github.com/ccheever/exact2/pull/1345): `ensureBun` names the pinned Bun for a test file | 42 | Open |
| 2026-11-02 | [#1346](https://github.com/ccheever/exact2/pull/1346): the patch check compares an app's paths through symlinks | 46 | Open |
| 2026-11-02 | [#1347](https://github.com/ccheever/exact2/pull/1347): `lock` names a dependency a package gained or lost | 15 | Open |
| 2026-11-02 | [#1348](https://github.com/ccheever/exact2/pull/1348): `verify` keeps a screenshot of each page its largest-text pass reads | 34 | Open |
| 2026-11-02 | [#1349](https://github.com/ccheever/exact2/pull/1349): three compiler refusals name the form to write | 36, 37, 41 | Open |
| 2026-11-03 | [#1355](https://github.com/ccheever/exact2/pull/1355): a `target/` folder copied from another checkout names where it was built | 30 | Open |
| 2026-11-03 | [#1356](https://github.com/ccheever/exact2/pull/1356): `ios --device` checks the iPhone Rust target before it builds | 22 | Open |
| 2026-11-03 | [#1358](https://github.com/ccheever/exact2/pull/1358): warn when a header readout holds nothing the iOS bar draws | 7 | Open |
| 2026-11-03 | [#1359](https://github.com/ccheever/exact2/pull/1359): `contract vocab` names a tag's attributes, the list styles, and an image's sources | 9, 10 | Open |
| 2026-11-03 | [#1361](https://github.com/ccheever/exact2/pull/1361): the edit-sheet recipe's header is its sheet's bar on iOS | 66 | Open |
| 2026-11-03 | [#1362](https://github.com/ccheever/exact2/pull/1362): the theme recipe's icon token has the `svg` source the web needs | 67 | Open |
| 2026-11-03 | [#1363](https://github.com/ccheever/exact2/pull/1363): the permissions recipe says a refused request runs no `then` | 72 | Open |
| 2026-11-03 | [#1364](https://github.com/ccheever/exact2/pull/1364): `contract vocab` answers `members`, and the grammar says what a members file may declare | 61 | Open |
| 2026-11-03 | [#1365](https://github.com/ccheever/exact2/pull/1365): `caps` counts a file's lines as `wc -l` does | 59 | Open |
| 2026-11-03 | [#1366](https://github.com/ccheever/exact2/pull/1366): the agent's help and the guide name `state media` and what a drive cannot show of a video | 62 | Open |
| 2026-11-03 | [#1367](https://github.com/ccheever/exact2/pull/1367): the search card says the bar hides while the person searches | 65 | Open |
| 2026-11-03 | [#1368](https://github.com/ccheever/exact2/pull/1368): `check` names the scale of a sheet iOS draws scaled under a target finding | 48 | Open |
| 2026-11-03 | [#1406](https://github.com/ccheever/exact2/pull/1406): a press at a point followed by `drag` names the drag's own start point, `from` | 56 | Open |
| 2026-11-03 | [#1407](https://github.com/ccheever/exact2/pull/1407): a link's spoken name counts a labelled image inside it, as on the web | 32 | Open |
| 2026-11-03 | [#1410](https://github.com/ccheever/exact2/pull/1410): a large title opens when a route with no bar turns into one with a large title | 76 | Open |
| 2026-11-03 | [#1411](https://github.com/ccheever/exact2/pull/1411): the reference says how a virtualized list shows a row that is not an item | 20 | Open |
