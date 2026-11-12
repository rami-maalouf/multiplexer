# iPhone feedback review: Beeper and Multiplexer

Documentation only, 2026-11-05. No agents, implementation, app builds, device access or server actions.

The supplied 3:58 recording was retrieved at 1206 x 2622 and reviewed across the full timeline. Local speech transcription and timestamped source frames support the findings. The video does not display a build identity; the recently delivered phone build is context, not a verified identification of this recording.

Screenshot timestamps below are references to private local evidence, not public
image links. The public repository intentionally does not contain these captures.

Raw evidence contains real chats and stays in gitignored `research/iphone-feedback-20261105/`. The safe issue descriptions below omit contact names, message bodies and private URLs. The local illustrated report is `research/iphone-feedback-20261105/report/index.html`; exact source PNGs, transcript and SHA256 manifest are alongside it.

## What matters first

1. Restore dependable interaction: no whole-list horizontal movement, no frozen scrolling after returning to the app, and usable row swipe actions.
2. Make available conversations appear without a blank loading interruption; assess cold and cached cases separately.
3. Replace heavy opaque chrome with the lighter, progressive material treatment demonstrated in Beeper, while preserving readability and accessibility.

Priority is proposed triage, not permission to start implementation. The user called horizontal drift the biggest problem. This review keeps all previous feature lanes halted.

## Evidence standard

- **Explicit** means spoken in the recording or added by the user in chat. **Visible** means supported by extracted frames. **Secondary** means an additional analyst observation.
- There are no touch coordinates, app logs, network traces or confirmed cache states. A still cannot establish a missed gesture, precise latency, blur implementation or root cause.
- This is a dark-mode recording. No light-mode or Reduce Transparency comparison was recorded. Colors and compressed video are not numerical contrast measurements.
- Prior host tests and signed-out checks remain valid within their scope; they do not close new authenticated physical-phone evidence.

## Issue inventory

| ID | Category | Priority | Requirement | Evidence |
|---|---|---|---|---|
| R01 | Functional | P1 | Keep the inbox and page fixed horizontally | 00:09-00:30 |
| R02 | Functional | P1 | Add row swipe actions, including a full swipe | 00:30-00:51 |
| R03 | Functional | P1 | Restore scrolling immediately when returning to the app | 00:58-01:16 |
| R04 | Functional | P1 | Stop replacing available chat history with a loading screen | 02:08-02:09; follow-up message |
| R05 | Visual | P2 | Make the inbox top edge translucent rather than a heavy dark band | 01:26-02:00 |
| R06 | Visual | P2 | Let inbox content remain perceptible beneath the floating bottom bar | 01:43-02:04 |
| R07 | Visual | P2 | Use a progressive chat-header treatment, including the status area | 02:08-02:56 |
| R08 | Visual | P2 | Make the composer field float over visible, softened conversation content | 02:56-03:22; 03:50-03:58 |
| R09 | Visual | P2 | Give Add and voice controls the same floating material treatment | 03:07-03:22 |
| R10 | Visual | P2 | Preserve the native translucent keyboard context | 03:22-03:37 |
| R11 | Secondary | P2 | Review rich link previews versus plain URL bubbles | 02:09 vs 02:16 and 03:06 |
| R12 | Secondary | P3 | Review inbox typography, density and visual hierarchy | 00:10 vs 01:32-01:41 |

### R01: Keep the inbox and page fixed horizontally

**P1 / Explicit request + visible defect / 00:09-00:30**

> Lists and pages are supposed to be single file ... up to down, not from left to right.

**Observation:** The title and bottom controls stay in place while the list shifts sideways. At 00:12, avatars and the beginning of row text are off the left edge. This is whole-list movement, not one row revealing actions.

**Required outcome:** Vertical lists remain aligned to the viewport. Horizontal gestures can operate a row action or navigation where appropriate, but cannot translate the whole list or clip all row leading edges.

**Acceptance:** On the actual iPhone, drag left/right and diagonally at several rows, after vertical scrolling and after app switching. List alignment remains fixed, vertical scrolling works, and no unintended chat opens on release. Repeat in the conversation list and other vertically scrolling pages.

**Likely source surface:** apps/multiplexer/app.contract:984 (rooms list), :1001 (row link); Exact IOS/ScrollViewIOS.swift and IOS/NodeViewIOS.swift axis/content sizing. Medium confidence in the host surface; root cause unproved.

**Existing work / limits:** Existing horizontal-list acceptance remains open. Finding 124 concerns drag-release link activation; that related fix does not prove absence of list panning.

**Screenshots:** 00:10 (`010s.png`, private local capture), 00:12 (`012s.png`, private local capture), 00:17 (`017s.png`, private local capture), 00:24 (`024s.png`, private local capture), 00:28 (`028s.png`, private local capture)

### R02: Add row swipe actions, including a full swipe

**P1 / Explicit request + Beeper demonstration / 00:30-00:51**

> If you slide left and ... slide right you get certain actions ... slide as well to completely do it.

**Observation:** Beeper moves one row and exposes Mute/Archive on one side and Unread on the other. The deeper swipe changes the action presentation. Multiplexer instead demonstrates whole-list drift.

**Required outcome:** A partial row swipe exposes the relevant actions. An intentional full swipe performs the primary action once. Cancellation restores the row. Exact full-swipe defaults need to be specified before implementation.

**Acceptance:** Verify both directions, partial reveal, tap an exposed action, full swipe, reversal and cancellation. Correct room only, one operation, truthful resulting state; vertical scrolling and edge-back remain distinct. Do not infer successful server mutation from this video.

**Likely source surface:** apps/multiplexer/app.contract:1001-1002 contains link/context-menu handling, with no row swipe action in this branch. Existing chat-menu actions around :1028 and changedChats are related behavior to reuse, not proof of gesture support. High confidence: missing row-gesture surface.

**Existing work / limits:** B7 long-press actions do not satisfy this swipe requirement.

**Screenshots:** 00:36 (`036s.png`, private local capture), 00:42 (`042s.png`, private local capture), 00:44 (`044s.png`, private local capture), 00:45 (`045s.png`, private local capture)

### R03: Restore scrolling immediately when returning to the app

**P1 / Explicit report + recorded recovery sequence / 00:58-01:16**

> When I leave the app ... and then come back to it, the scrolling freezes. I have to leave to a different page and then come back to the inbox.

**Observation:** The recording switches away and returns to Multiplexer. The user reports the list is unresponsive, then visits Archive and returns to the inbox. Touch events are not overlaid, so unchanged frames alone cannot establish how many drags were attempted.

**Required outcome:** The first intended scroll after foregrounding works, retaining the list position and active filter. No route switch or refresh should be needed to recover interaction.

**Acceptance:** On the phone, scroll midway, switch to another app, return, then immediately scroll both directions. Cover idle and in-progress scroll, background/foreground and lock/unlock. Record touches and response; confirm filter and position survive. Do not classify this as loading unless evidence connects them.

**Likely source surface:** apps/multiplexer/app.contract:984 rooms lifecycle; Exact IOS/ScrollViewIOS.swift, IOS/NavigationHostIOS.swift and foreground/gesture lifecycle are candidate surfaces. Low confidence on cause; no lifecycle reproduction or source diagnosis in this task.

**Existing work / limits:** Track separately from horizontal movement and chat swipe-back corruption.

**Screenshots:** 01:00 (`060s.png`, private local capture), 01:03 (`063s.png`, private local capture), 01:06 (`066s.png`, private local capture), 01:09 (`069s.png`, private local capture), 01:14 (`074s.png`, private local capture)

### R04: Stop replacing available chat history with a loading screen

**P1 / Follow-up report + visible spinner / 02:08-02:09; follow-up message**

> Loading still happens. [user follow-up]

**Observation:** At 02:08 a chat has its header but an otherwise blank body and spinner; by 02:09 messages are visible. These two extracted samples bracket a visible loading state, not precise tap-to-content latency or proof the room was cached. Later chat frames contain history.

**Required outcome:** Previously available conversation content appears immediately on return/reopen while fresh data is obtained. Genuine first-load, older-history and attachment loading remain distinct, honest states; already available text should not disappear.

**Acceptance:** Measure cold first open, warm reopen, app return, A-B-A, offline cached open, deep unread, old-history pagination and media loading separately. Preserve draft, unread anchor, room/visit identity and scroll position. Record first visible content from video, not only an API duration. Decide an explicit cold-load performance budget before implementation.

**Likely source surface:** apps/multiplexer/app.contract:1404-1411 loading branch; app.ts:448-491 thread answer; modules/apple/Matrix.swift:176; matrix-core/Sources/MatrixCore/MatrixAccount.swift:216-255 live timeline opening. High confidence in path, unproved bottleneck.

**Existing work / limits:** Cache foundation/placement checkpoints are not integrated into the phone build. Their fixture passes and older timings do not close this report; final-page delivery and deep-unread remain open.

**Screenshots:** 02:08 (`128s.png`, private local capture), 02:09 (`129s.png`, private local capture)

### R05: Make the inbox top edge translucent rather than a heavy dark band

**P2 / Explicit request + comparison / 01:26-02:00**

> The blur effect is a little weaker ... and it is nicer ... both at the top and the bottom.

**Observation:** Beeper keeps softened row content visible around/behind the compact Inbox header. Multiplexer has a larger, heavier title region and a stronger dark cutoff. There is some translucency in Multiplexer; the problem is not literally zero blur everywhere.

**Required outcome:** A lighter, graded top treatment preserves a sense of scrolling content beneath the header while title and status information remain readable.

**Acceptance:** Compare moving colorful/text rows at matched scroll positions in dark and light appearance, largest text and Reduce Transparency. No sharp content may collide with the status text; do not trade the opaque band for the already-known unprotected status-band defect.

**Likely source surface:** apps/multiplexer/inbox.contract:148-160 TitleMenu; app.contract:942-950 home header; Exact native cover/material ownership. High confidence on authored title, medium on material ownership.

**Existing work / limits:** Inbox status-band/background-extension work is unfinished. This is a product-level visual requirement, not proof that the proposed API is correct or sufficient.

**Screenshots:** 01:32 (`092s.png`, private local capture), 01:41 (`101s.png`, private local capture), 01:54 (`114s.png`, private local capture), 02:00 (`120s.png`, private local capture)

### R06: Let inbox content remain perceptible beneath the floating bottom bar

**P2 / Explicit request + comparison / 01:43-02:04**

> Things at the bottom [are] still visible behind the tab bars ... for us ... blacked out completely.

**Observation:** Beeper shows softened rows beneath and around the bottom capsule and separate controls. Multiplexer suppresses that content with a dark footer region and fade above it.

**Required outcome:** The capsule, Filter and Search read as floating material surfaces over the list, with controlled blur and readable icons. The bottom region must not look like an opaque shelf.

**Acceptance:** Capture the same moving high-contrast row crossing the footer in both directions, including the last row and home-indicator region. Preserve accessible hit targets, scroll clearance and a deliberate solid fallback under Reduce Transparency.

**Likely source surface:** apps/multiplexer/inbox.contract:68-74 draws a solid -exact-background backing to bottom=-40 plus 32px fade; :79 and :100 already use glass materials. High confidence that authored backing can hide the content those surfaces would sample.

**Existing work / limits:** App-level backdrop intent must be reviewed alongside native clearance; changing only a glass token may leave the opaque backing intact.

**Screenshots:** 01:41 (`101s.png`, private local capture), 01:54 (`114s.png`, private local capture), 02:00 (`120s.png`, private local capture)

### R07: Use a progressive chat-header treatment, including the status area

**P2 / Explicit request + comparison / 02:08-02:56**

> Behind the profile at the top ... text still shows. The blur only starts close to ... the top bars ... more defined around the safe area.

**Observation:** Beeper permits colored cards and message shapes behind the avatar/title and top controls, with stronger softening near the status region. Multiplexer clips/fades the conversation into a broad black header zone.

**Required outcome:** Retain visual continuity behind the floating profile, Back and More controls. Blur/occlusion should increase toward the status region rather than erase the whole header backdrop.

**Acceptance:** Inspect native scrolling through text, colored bubbles and media; verify status/time/battery and controls remain readable. Cover long title, merged-network tabs, rotation, large text, keyboard, and cancelled/completed back transitions. Never accept crisp message text over the clock.

**Likely source surface:** apps/multiplexer/chat.contract:54-61 explicitly supplies solid background from top=-120 through the bar plus a 32px fade; :84 title already uses glass. High confidence in authored opaque surface, not a complete compositor diagnosis.

**Existing work / limits:** Signed-out Settings tint/back proofs do not validate this authenticated chat header.

**Screenshots:** 02:09 (`129s.png`, private local capture), 02:16 (`136s.png`, private local capture), 02:25 (`145s.png`, private local capture), 02:34 (`154s.png`, private local capture), 02:44 (`164s.png`, private local capture), 03:53 (`233s.png`, private local capture)

### R08: Make the composer field float over visible, softened conversation content

**P2 / Explicit request + comparison / 02:56-03:22; 03:50-03:58**

> You can see the text kind of under ... Reply on WhatsApp ... the text input is liquid glass.

**Observation:** Beeper shows bubble/media colors and blurred content beneath the composer capsule. Multiplexer shows an outlined field on a solid black bottom bar; its placeholder is visually subdued against that surface.

**Required outcome:** A legible, native-feeling translucent input capsule with visible background context, without letting sharp conversation text compete with the draft or placeholder.

**Acceptance:** Compare keyboard hidden/shown, empty/typed/multiline draft, reply/edit, attachments and recording states, with content moving underneath. Draft text and placeholder remain legible; no content covers controls or steals touches. Preserve solid accessible fallback.

**Likely source surface:** apps/multiplexer/app.contract:1415 composer-bar has -exact-background; :1456 onward supplies outlined container and :1471 textarea. High confidence in explicit opaque parent; exact native input rendering still requires inspection.

**Existing work / limits:** Treat content-underlay, field material and keyboard geometry together; no cosmetic-only acceptance based on a static token.

**Screenshots:** 02:59 (`179s.png`, private local capture), 03:06 (`186s.png`, private local capture), 03:28 (`208s.png`, private local capture), 03:53 (`233s.png`, private local capture), 03:56 (`236s.png`, private local capture)

### R09: Give Add and voice controls the same floating material treatment

**P2 / Explicit request + comparison / 03:07-03:22**

> The plus button on the left and the voice note on the right ... are all liquid glass.

**Observation:** Beeper presents separate circular Add and voice surfaces outside the input capsule. Multiplexer has a separate Add circle but the waveform sits inside the outlined field; the opaque bar prevents comparable background visibility.

**Required outcome:** A coherent composer group with distinct, readable Add and voice actions and material continuity. Preserve the functional send/record states while specifying the desired voice-button grouping.

**Acceptance:** Capture Add, voice idle/recording/draft, Send and disabled states over text and media; verify target size, keyboard retention and no accidental send. Compare grouping and perceived weight, not just whether a blur property exists.

**Likely source surface:** apps/multiplexer/app.contract:1441-1490 composer row/VoiceButton placement; voice.contract:176 and AddButton component. High confidence in current hierarchy; mechanism for matching native material not established.

**Existing work / limits:** Existing Add/media/voice functionality is retained; the recording requests a visual/layout correction, not a new sending workflow.

**Screenshots:** 03:06 (`186s.png`, private local capture), 03:28 (`208s.png`, private local capture), 03:53 (`233s.png`, private local capture)

### R10: Preserve the native translucent keyboard context

**P2 / Explicit request + Beeper-only evidence / 03:22-03:37**

> Even under ... the keyboard ... it has a blur effect.

**Observation:** Beeper visibly samples the underlying colorful conversation through parts of the keyboard background. The recording does not show Multiplexer with its keyboard open in a comparable state.

**Required outcome:** Keep the system keyboard and allow the intended native background treatment where supported, without creating a custom imitation or breaking input/safe-area behavior.

**Acceptance:** First capture Multiplexer with the system keyboard open over colorful content, using matching OS/accessibility settings. Assess actual parity before calling it a confirmed defect. Verify safe-area transitions, scroll position, draft readability and Reduce Transparency.

**Likely source surface:** apps/multiplexer/app.contract:910 interactive-widget=resizes-content, :1471 native textarea and opaque composer parent. Exact keyboard/inset path is indirect and uninspected here. Medium/low confidence.

**Existing work / limits:** This is a documented requirement and missing comparison, not a reproduced Multiplexer keyboard bug.

**Screenshots:** 03:21 (`201s.png`, private local capture), 03:28 (`208s.png`, private local capture), 03:35 (`215s.png`, private local capture)

### R11: Review rich link previews versus plain URL bubbles

**P2 / Analyst observation, not an explicit narrated request / 02:09 vs 02:16 and 03:06**

**Observation:** Multiplexer shows underlined URL text bubbles; Beeper shows large video thumbnail/title/domain cards for visibly corresponding shared links. Room names differ across apps, and link-metadata availability was not inspected.

**Required outcome:** Decide whether rich previews are part of the desired daily-reading experience. If accepted, preserve safe URL display and a useful fallback when metadata is unavailable.

**Acceptance:** Use the same safe test URL and message across both apps, then compare with/without metadata, offline, long titles and failed thumbnails. Do not infer a fetch/cache bug solely from different recordings.

**Likely source surface:** apps/multiplexer/details.contract RichBalloon and app.contract text-message rendering; app.ts message mapping. Medium confidence: current text-link surface, rich-card capability not audited.

**Existing work / limits:** Keep separate from the explicit loading/material blockers and do not silently expand this documentation task into network preview implementation.

**Screenshots:** 02:09 (`129s.png`, private local capture), 02:16 (`136s.png`, private local capture), 03:06 (`186s.png`, private local capture)

### R12: Review inbox typography, density and visual hierarchy

**P3 / Analyst observation, not an explicit narrated request / 00:10 vs 01:32-01:41**

**Observation:** Multiplexer uses a larger, heavier scope title, denser rows, more prominent chevrons and timestamps. Beeper uses a compact title and a more spacious hierarchy. The examples have different filters, pinned state and some data, so they are not a pixel-identical layout test.

**Required outcome:** Choose consistent title, avatar, preview, time, badge and separator hierarchy that feels intentional at phone size; preserve fast scanning and accessibility. Beeper is a visual reference, not a requirement to copy every color or dimension.

**Acceptance:** Compare matched fixture data, filter, pinned state, font size and appearance. Inspect truncation, alignment and readable preview text at ordinary and accessibility sizes. Do not classify absent pins or differing unread counts from these unmatched states as bugs.

**Likely source surface:** apps/multiplexer/inbox.contract:148-160 TitleMenu; app.contract:1635 onward RoomFace/preview; inbox.contract:124 PinnedGrid. High confidence in style surfaces, no root-cause claim.

**Existing work / limits:** Existing B1/B6/B9-style parity goals provide context; this remains a secondary design review item.

**Screenshots:** 00:10 (`010s.png`, private local capture), 01:32 (`092s.png`, private local capture), 01:41 (`101s.png`, private local capture), 02:00 (`120s.png`, private local capture)

## Other visible differences and what they do not establish

- Beeper displays voice-note transcription affordances, different waveform sizing/speeds, rich cards and date-label styling. These are useful future reference details, but this narration does not request paid transcription or prove voice playback is broken. Existing voice tasks remain separate.
- Pinned contacts appear in Beeper's all-inbox view while Multiplexer is network-filtered. That does not demonstrate missing pins.
- Unread counts, chat ordering and preview content differ. Different filters, snapshots, aggregation and sync states prevent treating these as new correctness findings from this recording.
- Different accent colors are intentional settings, not defects. The requested similarity is material behavior, hierarchy and readable controls.
- No new evidence here establishes that release packaging caused any UI behavior. The installed development build and the release roster blocker are separate topics.

## Acceptance scenarios to carry into future work

- **Interaction:** vertical scroll, diagonal drag, both row swipe directions, cancellation/full swipe, return from another app and lock/unlock. Verify immediately on a physical phone.
- **Loading:** first open, warm reopen, A-B-A, foreground return, offline cached data, deep unread, pagination and media; preserve navigation and reading position.
- **Material:** move colorful media and text under inbox header/footer, chat header and composer; test keyboard open/closed, safe areas, large text, light/dark and Reduce Transparency.
- **Comparison discipline:** use matched fixture data and settings. Keep native screenshots/recordings of both apps where useful; never substitute an accessibility tree or a CSS/material token for visible acceptance.

## Decisions still needed before implementation

1. Confirm primary full-swipe actions for left and right; the demonstration establishes reveal/full-swipe behavior but not every final mutation/default.
2. Establish a cold-load performance budget; warm cached content must not be hidden behind unrelated work.
3. Capture Multiplexer's keyboard under the same conditions before labeling keyboard translucency a reproduced defect.
4. Decide whether rich link cards and the secondary density review join the immediate scope or follow the explicit blockers.

These questions do not block this evidence capture. No implementation plan or agent work was launched.
