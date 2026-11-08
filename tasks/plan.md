# Mux: plan

Mux (formerly Multiplexer) combines many chat networks into one inbox on a server I own.

## Status

**Agent CLI, read and guarded write commands implemented (2026-11-08, `feat/cli-c0`):**
Swift `mx` shares MatrixCore and the macOS SDK. Added JSONL read/search, foreground watch,
stdin recovery, confirmed text/reaction sends, explicit read receipts and Send Later.
All writes require an external exact account/room policy; dry-run and durable local audit
are built in. Reactions add only. One process owns the SDK store; stop watch before another
command. No daemon or MCP is needed for the scripted acceptance. Cold first-list order still
changes during SDK hydration; attempted readiness barriers did not prove completion and were
removed. Recovery lacked credentials in the first run; the expanded test fixture now verifies
it without resetting an existing backup. Real-account checks remain unverified. Results are in
`tasks/todo.md` and `tasks/evidence/cli-acceptance-20261108.json`. No real account was accessed.
Final review corrections passed 50 live checks and three unit tests. Audit records block
writes after an incomplete tail; postaccept audit errors cannot report a refused send.
Name resolution uses visible rows; search reports its bounded index scan. Rich attachment
and reply metadata remain a documented output limitation for follow-up.
Integrated current main `f6169a8`: additive plan/task conflicts retained both sides;
combined release build, three unit tests and 51 live acceptance checks passed.
The requested coverage expansion now passes 58 XCTest entries (57 substantive plus one
subprocess helper) and 18 named live scenarios, zero blocked. Valid recovery, encrypted
confirmed sends, merged reads/search, independent receipt observation and unscoped watch
are now verified on the test accounts. Fractional-second scheduling and postaccept output
failure reporting have regression fixes. `docs/cli-test-coverage.md` maps each command to
proof and retains the cold-order/watch-delivery/real-account limits.

**TestFlight build 4 uploaded (2026-11-08):** archive built with Exact tip
`ba8256a4a8` (mx-testflight + archive-refusal scope), notification extension packaged,
and App Store Connect upload succeeded (`Mux.ipa`). Extension Info.plist now carries
`DTPlatformName`, `DTPlatformVersion` and `UIRequiredDeviceCapabilities` (`arm64`) so
distribution export accepts it. ASC is processing the build for TestFlight.

**Main merge (2026-11-08):** PR #16 (`fix/release-readiness`) merged to `main`
(`2f5a35a`). Product fixes from #12 and #13 landed with it; #14 closed as
superseded. Exact archive-refusal scope is open as ccheever/exact2#1602 (clean;
needs Exact maintainer merge — no push on that repo). Next: TestFlight archive
build 4 with that Exact fix applied locally if upstream is not merged yet.

**R03 read-only phone recheck (2026-11-07):** with Rami's OK, scrolled the signed-in orbit
Mux inbox on the paired iPhone only (no chats opened, nothing sent or marked read). Home
put the app in `runningBackgroundSuspended`; after reopen, two more scrolls each changed
the visible rows. Freeze did not reproduce under automation. R03 stays open until a real
finger freeze is gone or a proved fix lands. Evidence `/tmp/mx-ready-r03/`.

**Release readiness continuation (2026-11-07):** branch `fix/release-readiness` holds
TestFlight push packaging (`90736ae`) and the production push gateway with a separate
scoped key (`7fcb305`). Controlled APNs probes for both environments returned the expected
rejection for invalid tokens. RoomKinds now retries failed bridged-kind lookups (unit tests
6/6 pass; uncommitted). Full MatrixCore run: 129 tests, 2 skipped, 1 failure
(`testANewLineFurtherBackThanTheChatLoads`, unread stayed 24). Self-host guide is in
`docs/self-hosting.md`. App PRs #12–#14 remain open and mergeable. Branch not pushed yet.

**Exact validation continuation (2026-11-07):** recovered the newer original-thread
checkpoint: Rami saved export compliance and build 2 showed Ready to Submit, assigned
to Teammates, which contained only its invited owner. The prior browser blocker below
is historical. App PRs #12, #13 and #14 and Exact #1560 are linked to this thread.
Exact text fade retiming sampled the clock twice, shifting the calculated endpoint
when execution was delayed between samples. Local commit `a7ae7d07b0` uses one sample
for progress and the layer clock origin. All 35 TextPlace iOS cases passed, including
the hosted pixel comparison; the existing endpoint assertion is unchanged. The endpoint
test also passed 100 consecutive repetitions, and caps passed. Feedback receipt:
`ac9481f6-814f-49b1-bbc1-33193c87b718` (one diary). This does
not resolve the separately observed fade-completion callback timeout. Earlier tracing
edits remain uncommitted and were present during this run. Navigation, menu and surface
candidates remain local. Broad prerequisite validation was stopped for disk pressure;
Cargo cleaned the disposable dev artifacts, recovering 24 GB free. No upload or shared
Exact integration was performed.

**Teammate-testing resumption (2026-11-07):** app fixes are committed in PR #14
(`fix/members-composer-groups`, stacked on #13). Recorded drives show matching group
counts, the composer mounted during first-open loading, corrected two-person bridged
groups, and the restored staged unread badge. Focused verification passed: 12 iOS,
13 app and 15 core tests. The full core run finished with 129 tests, two skipped and
two failures (unread count stayed 22; recovery first sync timed out). Both failed
cases passed together in isolation in 191.625 s; the full suite is not claimed green.
No product code or timeout was changed during resumption. The owned MX demo Simulator
is shut down. Remaining Exact work is committed locally in `exact2-rm-{expect,largetitle,menu,menusurface}`;
its broad native validation still contains failures, so those fixes were not published
or integrated. The drive CLI's 49 tests pass under pinned Bun 1.4.2; caps passes.
Browser snapshots timed out, including on a fresh tab, and the fallback browser host
is unavailable. TestFlight build 2's current compliance/installability is unverified;
Rami previously chose to answer France himself. PR #14 is not in build 2. Export
metadata remains unchanged pending that answer. The remaining diary was sent with
Rami's prior authorization: receipt `be9ec5d7-b554-4bc1-8762-38bedae7bf5a`.

**Push setup applied (2026-11-07):** after Rami's explicit approval, created a sandbox-only
APNs key restricted to `com.ramimaalouf.multiplexer`, stored and verified it in Keychain,
and deployed it through the playbook (0600, matrix:matrix; hash matches Keychain).
The App Group, both App IDs and two development profiles are configured; decoded profiles
cover the connected phone, shared group and this Mac's signing identity; the app grants
`aps-environment: development`. Cloudflare's DNS-only Sygnal CNAME is published.
Sygnal runs with only the sandbox app; HTTPS health is 200 with a valid certificate,
and an intentional invalid-token probe reached APNs and returned `BadDeviceToken`.
Production remains disabled. DNS now resolves through the Mac's system resolver too;
normal HTTPS health is 200 without address overrides or disabled verification.
The fresh app and extension are signed and installed on the connected iPhone; strict
signature verification and exact App Group/Keychain entitlements pass for both. Fixed
missing/dotted entitlement insertion and selected the existing signer's fingerprint.
Earlier signing errors did not reproduce after rebuilding the artifacts removed during
a pause; their precise cause remains unknown.
Rami opened the phone app, allowed notifications and locked it; APNs returned 200
and he confirmed the "New message" banner. A generic push through Sygnal also
returned no rejected pushkeys. On the Simulator, terminated-app plain and encrypted
notifications displayed sender/text, with 120 to 227 ms extension processing and
17 to 19 MB peak footprint. The focused core test passed in 76.578 s after aligning
its fresh-store initial-sync bootstrap with the existing 120 s test-device budget.
M3 is met (2026-11-07): with the phone locked, a natural WhatsApp message showed
its sender and text; Rami confirmed, and agents sent nothing through his chats.
P3.6 (mute/badge decisions) and P3.7 (tap routing / foreground suppression) remain
open. The test account signed out, its pusher count returned to zero, and the owned
simulator is off. No agent drive of the real account was performed.
Other feature lanes remain outside this authorization.

**Website and README (2026-11-06, `feat/mux-website`):** a root `README.md` (what Mux is, why,
how it works, how it was built; no other product named) and the production site in `website/`:
static HTML and CSS with a Three.js scene of the glass plane (three streams converging into its
nose), bundled with Bun; the scene loads after first paint and holds still for reduced motion.
Rami asked for Three.js and very little text, so it replaced the first version, an Exact site
(Exact findings 137 to 142 came from that one). Live at `mux.orbitlabs.studio` (Vercel project
`mux`, `website/deploy.sh`). A setup guide for others is the next document.

**Mux identity (2026-11-06):** Rami selected the three-fold glass paper plane and
named the app Mux. Visible app copy, manifest names, new Matrix device/push display
names, and voice-file vendor metadata now use Mux. The approved PNG is packaged
through the manifest's icon array; `docs/brand.md` records the artwork and palette.
Rami authorized sending only this session's Exact diary; receipt
`a83c1989-e345-4828-8cb5-60c983aeb0df` confirms one diary, zero commands and no
attachments. The 41 older unsent diaries and the command-log cursor were preserved.
Installation, Keychain, App Group, push and storage identifiers remain unchanged.
Native verification passed: 12 tests, light/dark checks and 14 largest-text
screens, clean in 124.4 s. The installed Home Screen icon and Mux label were
visually inspected, as were both sign-in appearances. Receipt:
`tasks/evidence/mux-branding-20261106.json`. Physical iPhone installation was not
part of this run. This authorization covers branding
only and does not reopen the halted feature queue below.

**R03 / capsule tabs (2026-11-07, `fix/r03-scroll-and-tabs`):** phone log still points at
`_UIFlexInteractionPanGestureRecognizer` (finding 151). An Exact `isEnabled` release workaround
did not fix the freeze on device and was reverted (`4251663c25`). R03 remains open. Capsule
Inbox↔Archive no longer re-keys `roomList` (`scopedInbox` + `inChatList`): kept. Exact tip
`4251663c25`.

**Daily chat chrome (2026-11-06, `fix/daily-chat-experience`):** mid-scroll keyboard rise
fixed in Exact (`KeyboardToolbarIOS` shifts offset when not at the end;
`exact2-multiplexer-integration` `ae8946aca0`). App: recording capsule has no stroke, Stop is
glass with a light red wash, draft cancel stays an X. Chat and inbox tops: the bottom bar's
recipe mirrored (dark material in dark mode, `chat.edge-bottom` tint), 85% through the status
bar, then an eased fade with no corner; always drawn; UIKit's own scroll edge effect off on the
inbox list and the transcript (it ended in a line at the status bar's foot). Rami: "barely
noticeable" on the iPhone (`.exact/edge-fix/line-d*`).

**Media drafts (2026-11-06):** picking a KLIPY GIF no longer sends it: it joins the composer
tray like photos (caption, remove, stack more); Send posts. Photos picker also accepts
videos into that tray. Proven on Simulator (`.exact/media-draft/`).

**New user-recorded iPhone feedback documented (2026-11-05):** reviewed the 3:58
Beeper/Multiplexer comparison, extracted 41 local-only source frames, and catalogued 12
requirements/observations with timestamps and acceptance criteria. The highest-priority
items are whole-list horizontal drift, missing row swipe actions, scrolling frozen after
foregrounding, and visible chat loading. Material requirements cover both inbox edges,
chat header/status area, composer field/actions and keyboard context. Keyboard parity is
reference-only until Multiplexer is captured with its keyboard open; link previews and
density are secondary observations. See `tasks/reviews/20261105-iphone-video-feedback.md`
and `tasks/evidence/iphone-feedback-video-20261105.json`. Private illustrated comparisons
live at `research/iphone-feedback-20261105/report/index.html`. This authorization was
analysis/documentation only: no agents or implementation resumed. Previous narrow test
passes do not close the newly recorded physical-phone defects.

**Separate user-requested iPhone delivery (2026-11-05):** the current integrated app
at `7ae795e`, framework `d0d66b1`, was built and installed on the paired iPhone 16 Pro.
Development executable `998edc18` is signed and its provisioning profile covers the phone;
the installation inventory matches its returned installation URL. The app was not launched
and no account was accessed. A preceding release attempt failed only at native-module roster
qualification for the target-only browser Swift package; preserve that failure separately.
Receipt: `tasks/evidence/iphone-build-20261105.json`. This request reopened only phone delivery,
not the halted feature lanes. Build and install resources were released afterward.

**Work halted early (2026-11-05, 07:30 UTC):** all related lanes and delegated tasks
are idle; no queued/running child appeared in the project inventory. All five owned MX
simulators are Shutdown and auth/core locks are absent. Both deadline alarms are disabled
after verified early stop. No implementation, review, build or test resumes without fresh
user authorization. Remaining work below is a handoff, not an active queue.

**User hard deadline (2026-11-05):** stop feature work and wind down all lanes at
07:44:48 UTC (02:44:48 Toronto); all related agents must halt by 07:49:48 UTC
(02:49:48 Toronto), 90 minutes after the user's request. Persistent coordinator alarms
are scheduled for 07:44:48.167Z and 07:49:48.089Z. Cancel delegated children, finish
owned-resource cleanup before the deadline, preserve incomplete evidence and do not
resume from late notifications without fresh user authorization. Disable both alarms
after the one-time stop. This deadline overrides the work queue below.

| | |
|---|---|
| Current phase | Phase 0 done: M0 passed on 2026-10-28 (Synapse and WhatsApp on our server). Phase 1 done on the practice account. Phase 2: daily reading and sending. |
| Beeper parity | Tasks B1 to B22 in `tasks/todo.md` ("Beeper parity"), from Rami's walkthrough (`research/beeper-walkthrough/report/index.html`, local only). Every question of the report is answered (decision log, 2026-11-02). Order: B1, then photos and files (B10, B11 with T2.12), then the rest of the inbox (B3 to B8), then push (Phase 3), then the chat details. Rules: D9 (Beeper's features, Messages' feel; dark mode first), D10 (GIFs from KLIPY), D11 (Send Later on our server). |
| Next task | Appearance settings are implemented on `work/appearance-accent`; final app-wide acceptance awaits the separate Exact navigation-root tint fix and native replay.  B22 Select Chats is complete (2026-11-03). Labels and shared-store preparation are integrated; remaining device proof waits for P3.0 and the iPhone checks. App, split across conversations (2026-11-03): "Later" tasks in `work/later-camera`: L1 (Camera in the + panel, photos) merged 2026-11-03, waits for a check on Rami's iPhone; Communities, Matrix invite Requests, New Space and preview sender fixes are now integrated from work/later-camera, including merged-chat membership compatibility. B14's "Message deleted" in the list and B7's other-device archive or delete are done (merged with the first-sync test fixes). Bookmarks (B14, B19, B20) merged 2026-11-03. B15's jump count and "New" line done 2026-11-03. B12 (GIFs, checked in WhatsApp) and B13 (Send Later) merged 2026-11-03. B18, B19, B20 and B21 merged 2026-11-03. Merged: B1, B3 to B11's photos and files. B2 applied on the server 2026-11-03; P3.0 is complete and sandbox push is installed (2026-11-07); M3 is met (locked-phone WhatsApp sender/text confirmed). Push without P3.0 done on the Simulator (2026-11-03, branch `work/push-prep`): MatrixCore's `PushContent`, the extension's fetch and the pusher (P3.2, P3.4), the permission, the token and the pusher in the app, the extension added after Exact's build (P3.1's script), and `send-test-push.sh` (dry run). Done 2026-11-02: B1, B3, B5, B6, T2.12, B10's "+", B11's photos and files. The chat bugs found on the way in T2.13 are fixed (2026-11-02): empty quotes, a reply hidden by the keyboard, messages showing through the composer, and drafts lost on quit. Server: Phase 0 done (M0 passed 2026-10-28, rechecked 2026-11-03 with 7 days of data). B6's pin check done (a pin cannot reach WhatsApp). M0's follow-ups applied 2026-11-03 (Rami: "do whatever you think is best"): a daily backup pull to the Mac, Instagram's debug log off, B2 (no network suffix in names), two images and our build cache deleted. P3.3 (Sygnal) is deployed with the approved sandbox-only key and DNS record (2026-11-07); production is disabled. |
| Blocked on Rami | M3 is met (locked-phone WhatsApp sender/text confirmed). P3.6 still needs his mute-copy and badge-count decisions; P3.7 needs Exact's remote activation/presentation hatch. Q5's cost part: the account is Pay As You Go (Rami, 2026-10-27), so Oracle's idle reclaim (for Always Free instances) should not apply; Cost Analysis shows whether 4 OCPUs and 24 GB cost money since June 2026. |
| Project | `/Users/rami/Documents/code/multiplexer` (own git repo, own T3 project) |
| Exact | Root host/compiler: `exact2-multiplexer-integration` at `4251663c25` (R03 release workaround reverted); package sources remain the identical normal `exact2` tree at `ed43ad09a0`. Cache harness retains its separately reviewed normal-checkout toolchain. |
| Last updated | 2026-11-08 |

Update this table at the end of every work session.

### Conversation assignments (2026-11-04)

Rami's next daily-use report is assigned to four existing conversations, all on GPT-6 Astra
or GPT-6.1 Sol, starting from integrated main `a09a33d`. Push owns unintended horizontal
inbox movement; Later owns cached chat opening; Exact/UI owns intermittent interactive
swipe-back layout corruption; Labels owns outgoing preview receipt icons. Reproduce the
gesture and loading defects before fixing them. Receipt indicators must distinguish actual
seen evidence from unavailable status. The coordinator integrates tested lane commits on
`fix/daily-chat-experience`; no lane independently merges main or publishes feedback.
Authenticated drives share `/tmp/mx-auth-drive.lock`; core tests retain their existing lock.
Each lane uses its own simulator and shuts it down when idle. All feedback stays local.

Additional appearance requirements from Rami: Settings offers arbitrary custom accent colors
with convenient presets and a reset to default blue; the choice persists and updates the app.
The former Bookmarks conversation now owns this feature on GPT-6.1 Sol. Exact/UI owns chat
header and composer materials; Push owns compact inbox header and inbox bar materials, each
after its gesture fix. Replace overly opaque black surfaces with actual backdrop blur/glass
that shows scrolling content behind controls, with readable light/dark and accessibility
fallbacks. Coordinate shared tint and material choices before integration.

Measured findings: sideways row drags activate navigation on release rather than overflowing
the inbox width (shared Exact finding 124, owned by Exact/UI). Cached rows were usable in
3 ms but first native reply waited 1,178 ms; repeat opens also clear the UI resource briefly.
The receipt SDK product `a2513d51` passed its locked host check and all 13 focused tests,
including the final redaction and cancellation controls. Separate tooling `b50927bd` fixed
the missing packaging destination parent; the official arm64 simulator build then passed.
Generated Swift bindings and a separate public-import smoke module compile and link. The
first isolated XCTest host build failed because its library search path omitted the SDK dylib
directory. The isolated path correction then built and passed one auth-free XCTest exercising
generated initialization and real Rust ClientBuilder construction/destruction; loaded and signed
embedded SDK hashes match. Actual Room methods, receipt callbacks, eligibility, merged-preview
and app integration proof remain pending. No production SDK pin changed.

The first Stage B runtime stopped at its HTTP login response guard before SDK restore:
the harness used the account domain instead of the discovered homeserver. The response
status/body was not retained, so its exact failure is unknown. Coordinator queried Synapse
read-only for the single requested test-device ID and found zero device and access-token
rows, resolving the cleanup uncertainty without another login or deletion. Discovery and
safe response diagnostics must be corrected before another Stage B run; no callback proof exists.

Stage B follow-up: discovery correction passed 12 injected Python tests and six auth-free
Swift endpoint tests. The corrected real boundary test then passed (12.440 s): exact preview
identity/readers, receipt-only Rust-to-Swift notification with unchanged preview, cancellation,
listener release and a fresh live control. The distinct-event comparator exercised -1/+1.
Both created test devices logged out and their tokens returned 401; independent device absence
was not queried. This supersedes the missing callback proof, not the preserved first failure.
MatrixCore eligibility, merged-preview identity and UI integration remain pending; source-only
adapter work is assigned to the receipt lane, with Cache coordinating shared-file ownership.
Adapter checkpoint `cbc2a5ee` remains nonshipping: 25 authored tests have not run, and full
member materialization, non-atomic eligibility reads and unbounded resident order scanning
remain open. Separate SDK source work is authorized for bounded cached membership evidence,
indexed receipt candidates and coherent evidence revisions; the validated SDK stays frozen.
The isolated state-store units now pass 15 exact offline host tests (five Memory, ten SQLite)
at `70280f77`, after preserving test-name and pinned enum-conversion compile failures.
Both receipt indexes remain. These tests establish their selected budget, revision, alias,
rollback and query assertions, not general planner/write-cost bounds. Comparator review
withheld approval over lease loss and unbounded retained-guard writer impact; high-level
composition remains paused pending a sound redesign.
Writer audit found that raw/legacy writers bypass proposed event revisions, while detached
persistence and resident publication lack an exact persisted baseline. New SQLite distinct-event,
stored and custom ordering therefore remain unsupported; no broad epoch/migration repair is
authorized. The next source design is bounded exact-identity receipt evidence using coherent
state/session checks. Only an eligible public receipt matching the preview's physical room and
exact event can establish Seen. Other cases remain unknown. This is limited positive coverage,
not full feature acceptance; the existing validated API and SDK artifacts stay unchanged.

Appearance app commits `dbff982` and `01b070d7` are integrated on the coordinator branch.
The follow-up fixes incoming-link contrast without changing chosen outgoing fills. Independent
review resolved its finding with no new actionable defects; the lane's exact final head passed
12 native tests and 14 body-53 screens in 124.7 s. The navigation-root header tint defect is
still open, so this is app source integration rather than full appearance acceptance.

Exact navigation lane: actual checkout `multiplexer-older`, branch
`fix/interactive-back-layout`, app base `a09a33d`. T3 still binds the thread to
`work-exact-gaps` at detached `9da752c`; that checkout remains untouched. A first
native cancelled/reversed Back and completed Back passed visually; intermittent
corruption remains unproven and needs keyboard/repeated-transition coverage.
Push's controlled native horizontal row drags confirmed a distinct release-time
link activation bug, tracked locally as finding 124. Its host regression builds in
isolated `exact2-navigation` on `local/interactive-navigation` at `ed43ad09a0`;
baseline runtime failed as expected (three drag activations). The isolated row-only
candidate passed 77 focused host tests with six scene-dependent skips. Partial
native replay passed left/right cancellation, vertical scrolling, ordinary tap,
reply/cancel and one keyboard-visible edge Back. The remaining named-store drive proved reversal cancellation (zero pushes), a
2 pt movement tap (one push), and native menu-button drag-out/back. The isolated
framework fix is committed as `7529006ab992ff021f790291fedd05b189250e81`; its diff
hash matches the tested candidate. Initial invalid attempts and capture provenance
remain recorded. Native Sign Out cleared the session; no exact server device ID
was captured, so server absence is not claimed. Normal
framework sources are unchanged. Normal exact2 and the `befb32d3cd` separator
experiment remain preserved. Chat material work follows navigation as a separate
change; the inbox lane owns home-only header/list composition. The lane holds no
auth lock and its simulator is off.

Labels progress: integrated `8904255` into `work/labels` (`673efb5`), preserving communities,
network-aware selection labels and SessionStore migration. The earlier integrated iOS verification
passed 8 tests and light, dark and largest-text checks. Four review findings are fixed in source:
pin metadata, bulk placement actions, stale picker membership and concurrent account-data writes.
The scoped follow-up review found no new actionable defects. Combined runtime tests passed 38/39,
including all ten Labels tests. The archive test failure was reproduced on isolated main `8904255`
and the Labels snapshot: inbox membership did not establish arrival of the exact prior own event,
so that event could arrive after re-archiving and remove the mark before the muted message.
The reply-preview timeout separately assumed a queued send was acknowledged. The test now checks
remote event identity and send acknowledgement, preserving archive behavior and wait limits.
Twelve corrected repetitions passed in 147.522 s; the exact worktree focused test passed in
99.199 s. The test-only correction is committed as `af5c49e`, with a clean scoped review.
Authenticated UI checks covered rename, duplicate validation, assignment/removal, filtering and
deletion preserving chats, including dark mode and largest text. The test user signed out.
Final iOS verification passed in 93.6 s after shortening the picker action to New Label:
9 tests, light/dark checks and 11 largest-text screens (`/tmp/mx-labels-final-verify2.log`).
Coordinator integration of complete head 2b55caf passed all 39 combined core tests with no failures or skips (1062.9 s). The integrated app/core sources match that head; the contract gate is clean and its 9-test iOS verification and screenshots remain applicable. See /tmp/mx-main-labels-2b55caf-core.xcresult and .log. This supersedes the earlier 38/39 run without erasing its diagnostic evidence.

Labels storage uses independent account-data fields and permanent deletion tombstones. A fresh
device discovers existing fields once; the SDK-local change marker invalidates cached reads after
changes. There is no recurring HTTP discovery timer, second sync cursor or local durable state.
Legacy documents remain readable and are not rewritten. Same-field writes follow server order;
simultaneous duplicate-name creates both survive. Bulk assignment can partially succeed on a
transport failure and is retryable. Older builds do not understand the new field overrides. If field writes succeed but their change marker fails, another device may keep cached data until another marker or a new session; the initiating write reports failure and can be retried.

Rami lifted the pause and requested GPT-6 Astra and GPT-6.1 Sol for the continuing conversations.
Labels (`work/labels`) and Later (`work/later-camera`) use GPT-6.1 Sol; the Exact/UI lane uses
GPT-6 Astra. The push lane uses GPT-6.1 Sol, preserves its duplicate Labels work in
`work/labels-finish`, and returns to push readiness without owning Labels. Completed lanes stay
closed. Any new delegated work in these lanes uses only these two models. Integrations into
`main` are coordinated here, one at a time, after each lane reports its tested commit.

## Goal

Own my messaging. One app on my iPhone (later my Mac) shows all my chats:
WhatsApp, Signal, Telegram, Instagram and others. Messages go through a server
that I control. No company can lock features behind a plan or close the code.

- **User now:** Rami only.
- **User later:** other people who run their own server (Phase 6).

### Non-goals (for now)

- Voice and video calls.
- iMessage (it needs a Mac connected to the server).
- Android, Windows, Linux clients.
- An installer for other people.
- Bridges that run on the phone (Beeper's "On-Device Connections").

## How to use this plan

1. Read **Status**, then the current phase in `tasks/todo.md`.
2. Work only on the current phase. Later phases are rough on purpose. We detail
   a phase at the checkpoint before it, with what we learned.
3. Before you choose work, check it against the **Decision rules**.
4. At each checkpoint: answer its questions, update **Status**, add to the
   **Decision log**, and get Rami's review. If a checkpoint fails, stop and
   change the plan before more work.
5. When a fact below is wrong or old, fix it here and say so in the log.

## Milestones

Each milestone is a thing Rami can see work. Each one is small and can fail.

| | Milestone | Proof |
|---|---|---|
| M0 | **Server proof** | A WhatsApp message sent to me shows in Element X on my iPhone, through my Oracle server. My reply from Element X arrives in WhatsApp. No code of ours. |
| M1 | **First own screen** | Our iOS app (Exact) in the Simulator lists my rooms and shows the last messages of the WhatsApp chat. Read only. |
| M2 | **Daily reading and sending** | On my physical iPhone: live updates, send text, unread counts. I use it for one week. |
| M3 | **Push notifications** | A WhatsApp message wakes my locked iPhone with the sender and the text. |
| M4 | **More networks** | Signal, Telegram and Instagram work. I connect a network from inside the app. |
| M5 | **Mac app** | The same app runs on my Mac. |
| M6 | **Others can install it** | A person can go from a new VPS to a working server with one guided setup. |

## Architecture

```
 Chat networks             Oracle server (aarch64)                    iPhone
 ─────────────             ───────────────────────                    ──────
 WhatsApp     ◄──────►     mautrix bridges (one per network)
 Signal, ...                     │
                                 ▼
                           Synapse + PostgreSQL   ◄── Matrix ──►      App (Exact UI)
                                 │                                      │ native module
                                 ▼                                      ▼
                           Sygnal (push gateway) ──► APNs ──►         MatrixCore (Swift)
                                                                        │ wraps
                           Traefik (TLS: 80, 443, 8448)                 matrix-rust-sdk
                                                                      Notification
                                                                      Service Extension
                                                                      (Phase 3, uses MatrixCore)
```

### Parts and their limits

| Part | Folder | Knows | Does not know |
|---|---|---|---|
| Server config | `server/` | The matrix-docker-ansible-deploy inventory: Synapse, PostgreSQL, Traefik, bridges, later Sygnal. | Anything about our client. |
| MatrixCore | `matrix-core/` | Matrix, through matrix-rust-sdk: sign in, sync, rooms, messages, send, encryption. | UI, Exact, Expo. |
| App | `apps/multiplexer/` | Screens (Contract), data (`app.ts`), one Swift native module that calls MatrixCore. | Matrix protocol details. It sees only MatrixCore's API. |
| Notification extension | later | Uses MatrixCore to fetch and decrypt one event. | UI. |

### Invariants

These must always be true. A change that breaks one needs a decision log entry.

1. The client talks only to our homeserver, with Matrix. It never talks to WhatsApp or another network. One exception (D10): GIF search calls KLIPY directly; KLIPY sees the search words and the phone's address, never a chat.
2. Only MatrixCore calls matrix-rust-sdk. The app and the extension call MatrixCore. This keeps the UI framework choice reversible (Expo is the fallback).
3. MatrixCore's public API uses plain types (strings, numbers, records). No SDK type leaks out.
4. No secret goes into git: passwords, access tokens, the APNs key, `vars.yml`.
5. We can rebuild the server from `server/` plus the secrets on a new VPS.
6. Every server change goes through the playbook. Manual commands on the server only read.
7. The agent works on the Mac. It reaches the server only over SSH (`Host oracle`).

## Decision rules

Use these to check that we work on the right thing.

1. **Prove before build.** Start each milestone with the smallest test that can fail.
2. **Biggest unknown first.** If two tasks are ready, do the one that can kill the plan.
3. **Use what exists.** The playbook, Element X and matrix-rust-sdk come before our own code.
4. **Thin slices.** Each task leaves something that works and that we can see.
5. **When Exact lacks something:** look in Exact's docs and LLPs first. Then use a native module in the app. Propose a change to Exact only if the app cannot do it.
6. **Three tries, then stop.** After three failed fix rounds on one problem, stop and write down the blocker.
7. **Rami decides** domain, names, deletions on the server, and anything that costs money.

## Decisions

| # | Decision | Reason |
|---|---|---|
| D1 | Bridges run on the server, not on the phone. | The server is always online. The client speaks only Matrix. On-device bridges need a Go runtime on iOS and special push work. |
| D2 | Homeserver: Synapse, installed by matrix-docker-ansible-deploy. | The playbook's default. Native sliding sync since Synapse 1.114, which matrix-rust-sdk and Element X use. |
| D3 | Client core: matrix-rust-sdk through `element-hq/matrix-rust-components-swift`, inside our own MatrixCore package. | The SDK that Element X uses. Apache-2.0. Has sync, encryption and a notification client. |
| D4 | iOS UI: Exact. Fallback: Expo, reusing MatrixCore. Confirmed at M1 (2026-10-27). | Native Mac app later from the same code. Chat UI work exists in Exact (`chat-thread` recipe, `apps/messages`, Excord). At M1, every screen used Exact's own parts and needed no change to Exact. |
| D5 | Element X is the client until our app is usable. | It works with our server from the first day. |
| D6 | First network: WhatsApp. | QR login (`login qr`). Simple to test. Confirm with Q3. |
| D7 | Work from the Mac. Manage the server over SSH and Ansible. | The iOS build needs Xcode. The playbook runs from the local computer. Safer than an agent with sudo on the server. |
| D8 | Build the client against a practice account on matrix.org until our server is ready. Its password stays in the Mac's Keychain, never in chat or git. | Unblocks Phase 1 while Phase 0 waits for the domain. matrix.org cannot host our bridges: a bridge must be registered on the homeserver by its admin. |
| D9 | Beeper's features, Messages' feel. Take every feature from Beeper (the whole inbox, its chat top bar, "Reply on WhatsApp", the full message menu, chat info, voice notes, photos, GIFs, Send Later). Keep what Messages already gives through Exact's recipe (bubble tails, sender runs, the long-press overlay, the "Replying to" bar, reaction pills). Follow the iPhone's light or dark setting; design and check dark first. | Rami, 2026-11-02: "Take the best from Beeper and Messages. I care more about the features of Beeper. But the user experience of Messages is pretty good, and if it's already there from the recipe, let's keep that." "I'll predominantly be using dark mode." |
| D10 | GIFs come from KLIPY. The phone calls KLIPY directly, the one exception to invariant 1. Rami makes the account; the key stays out of git. | Rami, 2026-11-02. Beeper uses KLIPY; Google shut down Tenor's API on 2026-06-30; KLIPY's test key is free (100 calls an hour), its production key is asked for with a form and has no published price, its ads can be turned off; KLIPY requires calls from the user's app, not through a server. GIPHY's production key has a fee. |
| D11 | Send Later: hold the Send button, as in Slack, and pick a time. The message waits on our server (Synapse's delayed events, MSC4140), so it goes with the phone off. Turning them on is a server change: Rami's OK first. | Rami, 2026-11-02. iOS does not promise to wake an app at an exact time; the SDK's bindings cannot send a delayed event, so MatrixCore calls the Matrix API itself (to check). |
| D12 | Agents reach the account through `mx`, a Swift command line on the Mac that links MatrixCore. Not a desktop app first, not Rust or TypeScript, not on the server. | Rami, 2026-11-08 ("go ahead"). Exact has no production door for agents (`exact agent` is development only; its MCP plan, LLP 1111, is parked). One copy of the chat logic: the app's own state (archive, merges, labels, ...) is account data that only MatrixCore reads and writes. The macOS SDK build also serves M5. On the server it would need the access token there (invariant 7). Fallback after 3 failed tries: Rust with matrix-sdk. |

## Facts we rely on

Checked on 2026-10-27. Recheck a fact before a task depends on it.

**Server (`ssh oracle`):** Ubuntu 24.04.5, aarch64, 4 CPUs, 23 GiB memory, 96 GB disk with 30 GB used (62 GB on 2026-11-03), Docker installed but disabled (since T0.5 the playbook runs it, on at boot). Ports 80, 443 and 8448 are free. Details: `server/notes/inventory.md` (T0.1). No host firewall is active (`iptables-persistent` was removed on 2025-08-11, so `/etc/iptables/rules.v4` is not loaded); Oracle's security list is the only firewall. No public IPv6. Time sync: `systemd-timesyncd`.

**Mac:** arm64, Xcode, Docker, uv, Homebrew, gh. Ansible 14.5.0 (ansible-core 2.21.5) through `uv tool`, installed by `server/setup.sh`. `just` is not needed.

**Oracle Always Free** ([docs](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)):
- The page lists 2 OCPUs and 12 GB of A1 as free. Our instance is larger, so check billing (Q5).
- Oracle can reclaim an instance if, over 7 days, CPU (95th percentile), network and memory use all stay below 20%.

**Playbook** ([matrix-docker-ansible-deploy](https://github.com/spantaleev/matrix-docker-ansible-deploy)):
- It runs from the local computer. It supports Ubuntu 18.04 or newer.
- It "somewhat supports" ARM. Only amd64 is fully supported. A component without an arm64 image is built on the server, if that component supports self-building.
- Ports: 80/tcp, 443/tcp and udp, 8448/tcp and udp.
- DNS: an A record for `matrix.<domain>`. The base domain delegates to it with `/.well-known/matrix/server`.
- It has no release tags. We pin a commit in `server/setup.sh` (`e3929968b8`, master on 2026-10-27).
- Install: `./server/playbook.sh --tags=install-all,ensure-matrix-users-created,start`.
- Check: `./server/playbook.sh --tags=self-check`.
- Add a user: `./server/register-user.sh <user> <keychain service> [admin]` (the playbook's `--tags=register-user`, with the password from the Keychain).
- The self-check requires the base domain's well-known files to equal the ones it generates. Its check of `/.well-known/matrix/client` does not follow redirects by default (`config.yml` turns that on).
- Its Docker role replaces `/etc/apt/sources.list.d/docker.list` with `docker.sources` (same repository) and turns Docker on at boot.
- Let's Encrypt needs no e-mail address (`traefik_config_certificatesResolvers_acme_email` stays empty).
- It puts Ketesa's settings into `/.well-known/matrix/client` even when Ketesa is off; `config.yml` turns that off, so the file is `m.homeserver` only.
- On aarch64, all 7 images of a Synapse-only install are pulled for arm64; nothing is built (`server/notes/install.md`).
- WhatsApp: `matrix_bridge_mautrix_whatsapp_enabled: true`. Double puppeting needs the Appservice Double Puppet service.

**Matrix homeserver domain:** you cannot change it after install.

**WhatsApp bridge** ([docs](https://docs.mau.fi/bridges/go/whatsapp/authentication.html)): send `login qr` to `@whatsappbot:<base domain>`. If the phone is offline for more than 2 weeks, linked devices disconnect.

**matrix-rust-components-swift** ([repo](https://github.com/element-hq/matrix-rust-components-swift)):
- Swift 5.9, iOS 16 minimum, Apache-2.0, iOS and the iOS Simulator only.
- Product `MatrixRustSDK` (a dynamic library). The binary target `MatrixSDKFFI` is an XCFramework downloaded from GitHub. Version 26.10.27.
- New releases are frequent, so pin the version.

**Exact** (`/Users/rami/Documents/code/exact/exact2`):
- New app: `bun scripts/exact.mjs new <path> --name <Name> --bundle-id <id>`. Set the name and the id before the first build.
- Only `docs/start-here.md` is required reading.
- A native module is `modules/apple/*.swift` or `*.xcframework`.
  - An `ExactModule` subclass answers `call` (on main, within 100 ms) and `later` (from any thread).
  - `context.changed("key")` asks every answer that called `native.watch("key")` again.
- Rust data sources hand all I/O to the host, so matrix-rust-sdk cannot run in one.
- Local notifications are built. Remote push is designed (`subscribePush()`, LLP 1133.004 §9) but not built.
  The app adds the token callbacks to Exact's app delegate at run time, and a script adds the
  notification extension and the push entitlements after Exact's build (2026-11-03).
- The iOS Simulator (26.5): `simctl push` runs no notification service extension; the Simulator
  gets a real APNs sandbox token once the app has `aps-environment` (`matrix-core/NOTES.md`, "Push").
- There is no notification extension target. The WidgetKit `.appex` build is a pattern for one.
- A general web view is out for v1.
- `docs/recipes/chat-thread.md` is the transcript and composer pattern.
- An app made by `exact new` runs `bun exact.mjs feedback status` at the start and keeps a diary in `.exact/diary/` (`docs/diary.md`). Nothing is sent without Rami's yes.

## Risks

| Risk | Impact | Mitigation | Found by |
|---|---|---|---|
| Something on the server already uses Docker or ports 80/443. | High | Inventory first. Rami decides what stays. | T0.1 |
| A component has no arm64 image and cannot self-build. | High | Note each image. Change the component, or move to an amd64 VPS. | T0.5, T0.6 |
| Exact cannot link matrix-rust-sdk. | High | A spike before any UI. Stop after 3 rounds. Fallback: Expo with the same MatrixCore. | T1.2 |
| Oracle reclaims an idle instance. | Medium | The server rebuilds from `server/`. Back up PostgreSQL. Check usage at the M0 checkpoint. (2026-11-03: the 7-day use meets all three idle conditions; the backups are on the same disk, so an off-server copy waits for Rami. Since 2026-11-03 the Mac pulls the dumps, media and signing key every day: `server/README.md`, Backups.) | M0 checkpoint |
| Unexpected Oracle charges for 4 CPUs and 23 GiB. | Medium | Rami checks billing. | Q5 |
| A network blocks logins from cloud IP addresses (not verified). | Medium | Test each network before we depend on it. | Phase 4 |
| The notification extension runs out of memory or fails to decrypt. | High for M3 | Test early in Phase 3. | Phase 3 |
| matrix-rust-components-swift is iOS only. | High for M5 | Build the SDK's Swift bindings for macOS ourselves. Done for the CLI (2026-11-08): `scripts/setup-cli-sdk.sh`. | Phase 5 |
| SDK API changes often. | Medium | Pin the version. Only MatrixCore touches the SDK. | Always |
| The bridges see message text, so a server breach exposes chats. | High | SSH keys only, few services, updates. End-to-bridge encryption is optional. | Phase 2 |

## Open questions

| # | Question | Blocks |
|---|---|---|
| Q1 | Which domain? User IDs become `@rami:<base domain>`. Does the base domain already host a website? (That decides how we serve `/.well-known/matrix/server`.) Answered 2026-10-27 (Rami): `ramimaalouf.com` (Vercel site; well-known files on the website's branch `matrix-well-known`), Synapse at `matrix.ramimaalouf.com`. | T0.5 |
| Q2 | ~~App name and bundle id~~ Answered 2026-10-27: Multiplexer, `com.ramimaalouf.multiplexer`. | T1.1 |
| Q3 | Is WhatsApp the right first network? | T0.6 |
| Q4 | ~~Which Apple Developer team signs device builds and owns the APNs key?~~ Answered 2026-10-27: `3V2UU7RRK9`. | Phase 2, Phase 3 |
| Q5 | Is the Oracle account Always Free or Pay As You Go? Is the 4 CPU / 23 GiB instance free on it? | Cost |
| Q6 | ~~Answered 2026-11-03 by the coordinator: Way A, default kept with the merge (Rami may override).~~ Merge Chats (todo.md, "Later"): a merged chat as one row that opens a switchable chat, with the networks as tabs in the chat bar (recommended: about two days, every chat feature keeps working), or Beeper's single combined timeline (several days, and every message action must follow its own network)? Should the default network follow the account to its other devices (Beeper's does not)? Recommended: the switchable chat first, the default kept with the merge. | Merge Chats |

## Decision log

| Date | Entry |
|---|---|
| 2026-10-27 | Plan created. D1 to D7 recorded. Rami is the only user for now. |
| 2026-10-27 | Project moved out of the `exact` folder to `/Users/rami/Documents/code/switchboard` and registered as its own T3 project. The Exact framework is only a dependency, used by path. |
| 2026-10-27 | Pulled the latest Exact. Its `main` history was rewritten on the remote, so local `main` now matches `origin/main` (`65577096ed`). The old local `main` is kept in exact2 as `backup/main-before-2026-10-27-rewrite`. The facts above still hold. |
| 2026-10-27 | Named the app **Multiplexer** (Rami). Bundle id `com.ramimaalouf.multiplexer`, following `com.ramimaalouf.openmulticam` and `com.ramimaalouf.opensplit`. Folder and T3 project renamed. Alternatives considered: Estuary (no messaging conflict, warmer), Switchboard, Braid, Hearth, Patchbay, Weft (each already used by a chat or social product). |
| 2026-10-27 | T1.2 passed: an Exact native module calls matrix-rust-sdk on the iOS Simulator (approach A: the release's xcframework and Swift bindings in `modules/apple/`). Exact refuses symlinks in the app, so `scripts/setup-matrix-sdk.sh` copies them. Cost to watch: each module edit recompiles 2 MB of bindings (about 40 s). Details in `matrix-core/NOTES.md`. D4 (Exact) stands. |
| 2026-10-27 | D8: Rami chose to build the client against matrix.org for now. The domain (Q1) is still needed for Phase 0. |
| 2026-10-27 | T1.3 passed on matrix.org with `@rami-m-test:matrix.org` (password in the Keychain, service `multiplexer-test-account`). MatrixCore builds as a Swift package with the pinned SDK and inside the Exact app. The WhatsApp part of T1.3 waits for T0.6. |
| 2026-10-27 | T1.4 passed on the practice account: sign in, an alert that names why a sign-in failed, the session kept across launches, and Sign Out. The session is in the Keychain (`SessionKeychain` in MatrixCore, this device only, readable after the first unlock for the later notification extension). The SDK's store is a folder in the app's data; a Keychain session whose folder is gone (a reinstall) counts as signed out. The app's tests run on iOS only: the web has no Matrix SDK. |
| 2026-10-27 | T1.5 passed on the practice account: a plain room list (name, time, 2-line preview, newest first) and a read-only chat (the last 20 messages, opened at the newest, `chat-thread` bubbles). Fixed a race in MatrixCore: `settle()` could read the timeline before a pagination's diffs arrived. The authored tests cannot sign in, so drives check these screens. |
| 2026-10-27 | Checkpoint M1 (without its WhatsApp part, which waits for Phase 0): Rami chose to continue with Exact (D4). Exact now has a feedback flow for the app's diary (`bun exact.mjs feedback`); keep the diary for each task. Phase 2 written in detail. |
| 2026-10-27 | Pulled the latest Exact. Its history was rewritten again (a transcript purged on purpose), so local `main` now matches `origin/main` (`cee509ac82`). The old local `main` is kept as `backup/main-before-2026-10-27-rewrite-2`. |
| 2026-10-27 | Sent the app's Exact diaries with Rami's yes (receipt `4c8a0a07-60a8-466e-ae9a-bef9a0b29f82`; `bun exact.mjs feedback delete <receipt>` takes it back). |
| 2026-10-27 | T2.1 passed: a session whose store is gone, or whose Sign Out could not reach the server, waits in a second Keychain slot and is signed out on the server in the background. Tests and drives no longer leave devices on the practice account. |
| 2026-10-27 | T0.1 done (read only): ports 80, 443 and 8448 are free; Docker is disabled; old n8n and Postiz images (13 GB) and volumes (294 MB) remain; T3 Code and Syncthing run and do not conflict. Rami decides what stays. |
| 2026-10-27 | T2.2 passed: MatrixCore watches the room list and keeps one live timeline per opened chat; the module passes changes to `app.ts` as `context.changed` topics. A new message shows in 1 to 2 s, and a reader scrolled up keeps their place. |
| 2026-10-27 | T2.3 passed, except the offline case (needs a device, T2.7): the composer sends through the room's send queue; a message shows at once, dimmed, then sent; a failed one shows "Not Delivered" with Try Again and Delete. |
| 2026-10-27 | Rami: keep the old Docker data on the server; set up the server now. Phase 0 runs in a second conversation, in its own worktree on the branch `server/phase-0`, merged into `main` by the app conversation. The domain recommendation is `@rami:ramimaalouf.com`; Rami confirms it before the install. |
| 2026-10-27 | T2.5 passed: photo messages show at their ratio, download through the sdk into the app's cache, and open in a full-screen viewer. |
| 2026-10-27 | T2.8 added and passed: scrolling up a chat loads 20 older messages at a time, to the room's first message, and keeps the reader's place. A test sign-in now signs out in a teardown, so a failed test leaves no device on the account. |
| 2026-10-27 | Rami keeps the two leftover test devices on the practice account (`B7E9i45YI2`, `fzw1iUkJqS`). Do not remove them. |
| 2026-10-27 | T0.3 done: Ansible 14.5.0 on the Mac; the playbook pinned at `e3929968b8`; our inventory reaches the server as `oracle` and answers `pong`. The settings are in `config.yml` (in git); only the two secrets are in the gitignored `vars.yml`, written from the Keychain (service `multiplexer-server`), so the server can be rebuilt from `server/` plus the Keychain. |
| 2026-10-27 | Found in T0.3 (read only): the host firewall blocks nothing (`rules.v4` is not loaded since `iptables-persistent` was removed), so T0.4 needs no host change. The T0.1 inventory said otherwise; corrected there. From the Mac, TCP 80 and 443 pass Oracle's security list and 8448 does not. |
| 2026-10-27 | The website's well-known files are ready on the portfolio repo's branch `matrix-well-known` (commit `80e243a`, not pushed): `server` and `client` in `public/.well-known/matrix/`, served as JSON, `client` with CORS. matrix-rust-sdk sets no redirect policy, so Element X and our app follow `ramimaalouf.com`'s 301 to `www`. |
| 2026-10-27 | T2.6, first part: encrypted chats show new messages as text, and a message without its key shows "Waiting for this message". The practice account has no recovery set up; the recovery key waits for a test user on our server, so the practice account Rami also uses in Element keeps no new encryption identity. |
| 2026-10-27 | T2.9 added and passed: pictures (or initials) in the chat list. The list now uses the room list service's order instead of sorting by the last message's time, which was empty for a room whose newest event is no message. |
| 2026-10-27 | T0.2 done. Rami confirmed the server name `ramimaalouf.com` (user IDs `@name:ramimaalouf.com`, Synapse at `matrix.ramimaalouf.com`; it can never change), and that the playbook may replace `docker.list` with `docker.sources`. Cloudflare has `A matrix -> 192.18.154.172`, DNS only. |
| 2026-10-27 | T0.5 install done: Synapse 1.164.0, PostgreSQL 18.6 and Traefik run on the Oracle server, all arm64 images. `https://matrix.ramimaalouf.com` has a Let's Encrypt certificate and password sign-in. Users `@rami` (admin), `@test1`, `@test2` exist; passwords only in the Keychain. The self-check waits for port 8448 and the website: with Rami's yes, the website commit `80e243a` went to its `main`, but Vercel's production deploy failed (cause not known yet). |
| 2026-10-27 | The website's Matrix files are live (`ramimaalouf.com/.well-known/matrix/{server,client}`, through the 301 to `www`). Its deploys had failed since Vercel dropped Node 20; with Rami's go-ahead to merge, the website moved to Node 24 with a small post-build script for the Astro 4 adapter's function runtime, checked on a preview deploy first. Upgrading the website to Astro 5 or newer would remove the script. |
| 2026-10-27 | T0.4 done: Rami added TCP 8448, UDP 443 and UDP 8448 to the Oracle security list (VCN `vcn-20250515-0038`, Default Security List). The playbook's self-check is all green, and matrix.org's federation tester finds `ramimaalouf.com` through the website's 301 (`FederationOK: True`). |
| 2026-10-27 | First messages: `@rami:ramimaalouf.com` (Element Web, through `www.ramimaalouf.com`) and Rami's own `@rami-m:matrix.org` exchanged encrypted messages in a new room, both ways. Federation works. T0.5 now waits only for Element X on the iPhone. |
| 2026-10-27 | T0.5 done: Element X on Rami's iPhone signed in to `@rami:ramimaalouf.com`, was verified from Element Web, and sent an encrypted message. One hour after the install the server used 1.8 GiB of 23 GiB, load 0.08. |
| 2026-10-27 | T0.6, first part: the WhatsApp bridge (mautrix-whatsapp `v0.2610.0`, arm64 image) and Appservice Double Puppet run; Rami linked WhatsApp, and his chats and their history arrive in Element X. Bridged rooms are not end-to-end encrypted (the playbook's default). During the history sync the server's load rose to 2.35 and memory to 2.4 GiB. |
| 2026-10-27 | T0.6 done: WhatsApp messages flow both ways through our server, with double puppeting (Rami, in Element X). 265 of 267 WhatsApp chats became rooms with their history. `@rami:ramimaalouf.com` now holds Rami's real WhatsApp chats: a message sent there reaches a real person. |
| 2026-10-27 | The server conversation's review ("is the app ready for prime time?"): not yet. Turned into T2.10 (the real account, read only), T2.11 (WhatsApp message kinds), T2.12 (send photos) and Phase 3's parts. Rami: a read-only drive on `@rami:ramimaalouf.com` is OK; Q4 is team `3V2UU7RRK9`. Safety rule: tests send only as `@test1` or `@test2`; nothing is ever sent, reacted to, deleted or marked read on `@rami` from a test. |
| 2026-10-27 | T2.10 passed, read only on `@rami` (signed out after): 254 chats (269 rooms, 15 spaces hidden), a usable list 0.7 s after sign-in, 59 MB footprint. Fixed: spaces showed as chats; senders showed as raw ids until the chat loads its members. The MatrixCore tests now run as `@test1` on our server. M1's last item is done. |
| 2026-10-27 | T2.7 passed on Rami's iPhone 16 Pro (team `3V2UU7RRK9`, the wildcard development profile): it installs, signs in, relaunches signed in, shows chats and sends. Exact's agent drives the phone too (`agent ios --device --phone <udid>`). The offline check waits for Rami. |
| 2026-10-27 | T2.4 passed with `@test1` and `@test2`: unread counts in the chat list; opening a chat sends a read receipt. In a drive, receipts go out only for `@test` users, so a read-only drive on `@rami` cannot mark a chat read. `scripts/send-test-message.sh` now sends as `@test2` by default and refuses `@rami`. |
| 2026-10-28 | M0 passed, without the 48-hour wait (Rami: he uses it daily and sees a disconnect himself). Added a small daily database backup on the server (the playbook's `postgres-backup`: 7 daily and 2 weekly dumps, no monthly, a dump at each container start; first dump 42 MB, intact). It does not cover media or the loss of the server; an off-server copy waits for Rami. |
| 2026-10-28 | Rami asked for Instagram ideas in a separate chat (branch `connectors/instagram`, docs only). It tests the account and cloud-IP risks before any build; Phase 4 stays after M2 and M3. |
| 2026-10-31 | Rami: the app must look and work like Beeper's iOS app ("very native and intuitive"), most important first. His walkthrough video is analysed in `research/beeper-walkthrough/report/index.html` (local only; `research/` is gitignored because the video shows real chats): 18 topics with his exact words, clips, stills, what to build, 23 open questions and a proposed order. His top wants, in his words: filter by network ("what I care about the most"), the unread filter, pinned people, photos and GIFs ("the two most important"), then Send Later. Read-only checks: Exact supports 14 of the 21 UI patterns fully and 7 partly (a Swift view covers each gap); the SDK has an API for 19 of 24 features (gaps: writing custom tags for Archive and labels, forward, scheduled sending, search inside one chat, jump to a date). |
| 2026-10-31 | Rami: pull the latest Exact, and bring the chat parts of its sample apps (`apps/messages`, `apps/excord`) into our chat. Exact moved from `cee509ac82` to `1bc4c36cb7` (1,045 commits, a fast-forward; `git reset --hard cee509ac82` in exact2 takes it back). `exact update` refreshed the generated files; the app builds, its 3 tests pass, and a drive as `@test1` signs in and opens a chat. |
| 2026-10-31 | T2.13 passed: bubbles with tails and sender runs, swipe to reply with quotes, reactions, "Edited", and a long-press menu with Beeper's quick reactions. Exact feedback 23 to 27 recorded. |
| 2026-11-02 | Rami answered part of the Beeper report (in another conversation, which also reviewed the report against T2.13). Answers: filter by network in a sheet from the bottom bar, as in Beeper; the sheet has exactly Beeper's list; communities later ("whatever is easiest"); no dashed slot in the bottom bar; a dot on an unread pinned picture, as in Messages; remove "(WA)" and show a network logo (the server change waits for his OK at that time); follow the iPhone's light or dark setting with Beeper's layout, dark first ("I'll predominantly be using dark mode"); a reply keeps the chat visible with the "Replying to" bar (built in T2.13). New decision D9: Beeper's features, Messages' feel. Still open: archive-rule, preview-read, labels-meaning, search-scope, gif-provider, send-later, poll, voice-pause, speed-scope, transcribe, bookmarks, expiry, remind-me, merge-chats, push-order, and the unclear quote at 4:35. |
| 2026-11-02 | The review's corrections to the report: topics 10, 17 and 18's "our app today" predate T2.13; a message's menu is the app's own overlay, not Exact's native menu (no reactions row: Exact finding 27; the newest Exact, `ed43ad09a0`, changes none of the 7 partly supported patterns); the reaction bar has Beeper's six fixed emojis; every message load marks a chat read today (a fix is in progress in another conversation); "(WA)" also shows above sender runs, in quotes and in the reply bar; MatrixCore tests prove reply, reactions and reading "Edited", not yet sending an edit, deleting a sent message, recent emojis or "Seen by". The report's proposed order became tasks B1 to B21 in `tasks/todo.md`, the inbox first. The review's suggestions (photos earlier, the top bar with the info page, "Reply on WhatsApp" after the network work) are not approved yet. |
| 2026-11-02 | Chat fixes from a read-only review against Exact's sample chat apps (`apps/messages`, `apps/excord`), each reproduced first in a drive as `@test1`: each chat keeps its own draft and reply (a reply started in one chat had gone out in another, quoting a message there: a message's id names a message only in its own chat); leaving a chat closes its long-press menu; a chat is marked read only once its newest message has been in view for a second, or when the reader leaves from there (the load no longer marks read; `markRead` is its own request; `sendsReadReceipts` unchanged); the swiped bubble springs back, with one haptic. The bubble already followed the finger: the 2026-10-31 note that it cannot was wrong (Exact finding 28). Drafts last until the app quits. |
| 2026-11-02 | Pulled the latest Exact: `1bc4c36cb7` to `ed43ad09a0` (339 commits, a fast-forward; `git reset --hard 1bc4c36cb7` in exact2 takes it back). No app code changes: `exact update` refreshed `AGENTS.md` (a new `feedback note` command) and `Cargo.lock`; `lock` said no changes (finding 15 again). `test ios` 3 passed, `verify ios` clean, drives clean in light and dark. Finding 21 (`rem` inside `min()`) is fixed there. origin has newer commits than `ed43ad09a0`; not taken. |
| 2026-11-02 | Rami answered every open question of the Beeper report. Preview of a held chat: does not mark it read. Archive: a new message brings a chat back, unless it is muted. Labels: a named group of chats, later ("not a requirement"). Search: chats, then messages, then links. The + panel: photos from the library and files first; a built-in camera later; no polls for now. Voice notes: tap to start, tap to finish, listen, send; no pause. One playback speed for voice notes only, not videos. Transcribe: later. Bookmarks: in each chat's info page and in one list. Message expiry: kept, last. Remind Me and Merge Chats: later. Delete a chat: from our app only, WhatsApp keeps it. Push notifications: after the inbox tasks (B1 to B8). First task: B1, then photos and files. GIFs: KLIPY (D10). Send Later: hold Send, as in Slack, kept on our server (D11); this also answers the unclear quote at 4:35. `tasks/todo.md` updated: the order, each task's answers, and a "Later" list. |
| 2026-11-02 | B1 passed and merged (agent in worktree `multiplexer-network`): each chat's network comes from the bridge bot named in `io.element.functional_members` (the SDK returns no `m.bridge` state), and its logo shows on the chat's picture. Rami's real account, read only: 292 chats, 259 WhatsApp, 30 Instagram, 3 Matrix. Rami allowed read-only drives on any account ("u can use any acct"); writes stay on the test users. Parallel work: one worktree and one simulator per agent (`multiplexer-<name>` beside the main checkout, so Exact's relative paths hold; simulators "MX <name>", iOS 26.5). A `target/` copied from another checkout fails the build (Exact finding 30): build each worktree fresh. `scripts/test-matrix-core.sh` needs `SIMULATOR="<name>,OS=26.5"` when a name could match several iOS versions. Exact feedback 30 to 32 recorded. |
| 2026-11-02 | Phase 3 (push) detailed from a read-only research into tasks P3.0 to P3.7. Exact has no remote push and cannot build or sign a notification extension, so a script of ours adds the extension after Exact's device build (P3.1, the biggest unknown); the SDK has the notification client and `setPusher`; the server needs Sygnal under `sygnal.ramimaalouf.com`. TestFlight stays blocked by Exact's archive check; development builds are not. Rami's part (P3.0) can start now. |
| 2026-11-02 | Merged into `main`: the inbox's floating bar, filter menu (All, Unread, Unanswered, DMs, Groups) and pinned chats (B3, B5, B6), and sending photos and files from a "+" panel (T2.12, B10's "+", B11). Each branch was merged with `main` in its own worktree first and tested there (`verify ios` clean; the network, inbox, photo, file and reply tests pass), then `main` moved forward to it. Rami's real account, read only: the filters and the bar work on 292 chats; no chat is pinned there. Open: the iOS edge effect under the bar (Exact finding 35); a pin on `@rami` may pin in WhatsApp too (ask Rami first). Exact feedback 35 to 41 recorded; the chat-fixes conversation sent the pending diaries (receipt `f63c011a`) with Rami's yes. |
| 2026-11-02 | Fixed the chat bugs found on the way in T2.13 (each reproduced first as `@test1`): a reply's quote stayed empty (MatrixCore asked the sdk with the quoted message's id instead of the reply's); a reply started low on the screen ended under the keyboard; scrolled messages showed through the reply bar and the composer (they now share one bar in the page's colour); drafts were lost when the app quit (now kept per chat in the account's store, with the message a reply answers). This session builds and drives on its own Simulator ("MX fixes", `EXACT_SIM`), because parallel sessions shared the default one (Exact finding 43). Exact findings 43 to 45. |
| 2026-11-02 | B4 merged: the filter sheet from the bottom bar's up-down button, with Inbox, Matrix and one row per network, each with its unread chats' count; the choice combines with the filter menu and persists. Merged with `main` (drafts, reply arrow) and tested in its worktree first. Exact feedback 48 to 50 recorded. |
| 2026-11-03 | B7 and B8 merged: a chat's long-press menu (Archive, Move to Low Priority, Pin, Mark as Unread, Mute, Delete), muted rows with a bell and grey counts, and Archive and Low Priority lists in the bar and the sheet. Archive and Delete live in one account data event, because the SDK cannot read a custom tag's current value; Delete never leaves a bridged room (with mautrix's `bridge_matrix_leave` on, it would leave the WhatsApp group). Nothing of this reaches WhatsApp except Mark as Read. Exact feedback 51 and 52. |
| 2026-11-03 | B9 and B10 merged: the chat's own top bar (Back with the inbox's other unread chats, the picture with its network logo and the name in a glass capsule, "..." with Pin, Mark as Unread and Mute), which also ends T2.13's sharp bar above the long-press blur; and "Reply on <network>" with the network's logo in the text field. Exact feedback 53 to 56. |
| 2026-11-03 | Fixed the app's open Exact findings in pull requests to exact2, each reproduced first on its newest commit (`880d4f8652`), as Rami asked ("well defined: make a PR"): #1329 (43: `ios --run` waits for a running drive), #1337 (38: a HEIC over 256 KiB showed empty), #1338 to #1340 (13, 17, 47: agent messages), #1341 and #1342 (9, 11, 24, 39: docs), #1343 and #1348 (37, 34: `verify`), #1344 to #1347 (23, 42, 46, 15: `update`, `ensureBun`, the patch check, `lock`), #1349 (36, 37, 41: compiler refusals). Then #1355, #1356, #1358 and #1359 (30, 22, 7, 9 and 10). Design questions stay feedback, which waits for Rami's yes. New findings 57 to 59, first numbered 51 to 53 (host tests need the Metal toolchain and run all 318 classes; `caps` counts one more line than `wc -l`). |
| 2026-11-03 | B15 merged, with T2.11's videos: a "New" line (a chat with many unread messages opens there, as in Beeper), a jump-to-latest button with the unread count, "Seen by" in groups and "Seen" in DMs, one header per day or gap ("Today 9:41 AM"), large emoji and stickers with no bubble, tappable links (Safari's in-app view), and videos with a poster that play full screen. A quote showed its sender's raw id when the chat loaded before its members (the SDK copies the quoted sender without a profile); MatrixCore now names it. Exact feedback 60 to 63; another conversation's 51 to 53 became 57 to 59 (the numbers were taken). |
| 2026-11-03 | B14 merged: the full message menu (Reply, Share, Forward to several chats with search, Copy, Mark as Unread, Edit and Delete for your own), long press on every kind, and the emoji sheet with the account's own frequent emojis (shared with Element). A drive refuses react, edit, delete, forward and Reset on any account that is not a test user. After a merge that adds a package (B15's in-app browser), run `bun install` in `apps/multiplexer` before building `main`. Exact feedback 64 to 68. |
| 2026-11-03 | B16 and B17 merged: voice notes play with a drawn waveform and one app-wide speed; record with tap to start and finish, a draft to play or delete, and Opus sent as `m.audio` voice events. Exact feedback 69 to 72. |
| 2026-11-03 | B21 merged: the inbox draws its own "Inbox" title row with a pull-down menu (Select Chats and Merge Chats greyed, Settings), because Exact's large title cannot open a menu; the title no longer shrinks on scroll. Settings: account, voice note speed (the same setting as the chip), Sign Out, version. Exact feedback 73 to 76. |
| 2026-11-03 | B20 built on branch `work/b20-chat-info` (not merged): the chat info page zooms out of the chat bar's capsule, with the picture, name, network and member count, Search (disabled until B19), Archive or Unpin, Low Priority, More (Pin, Mark as Read, Mute, Delete), the newest photos and videos, members, Edit Group Info (name and picture), Customize for Me (a name only you see, in global account data `com.ramimaalouf.multiplexer.names`: the SDK cannot write custom room account data), and Add Member for plain Matrix groups only. Bookmarks wait for B14's bookmarks; Jump to Date has no SDK call. |
| 2026-11-03 | B20 merged: the chat info page. Exact feedback 83 to 85 (B18 holds 77 to 82). |
| 2026-11-03 | Rami: "all suggestions ok". Filter sheet: the Matrix row stays first, numbers count unread chats. A pin stays in our app and never pins in WhatsApp. A deleted chat that comes back shows only its new messages. Your own message brings an archived chat back. A mention in a muted chat shows "@" with no push. WhatsApp mutes show the bell. Mark as Unread inside a chat goes back to the list; Back's count leaves out muted, archived and Low Priority. A chat opens at the "New" line. Your own message says "Sent", not "Delivered" (our server has it, not WhatsApp). Links open in Safari's in-app view. Typing indicator: later. Mark as Unread marks the whole chat; no "Forwarded" label; Edit and Delete hide after WhatsApp's limits; no skin tones. Info page subtitle uses "·"; Add Member hidden in bridged groups. The inbox keeps its own "Inbox" title row; Select Chats and Merge Chats stay greyed. Still waiting (not suggestions): removing "(WA)" (server), the KLIPY account, delayed events (server), Apple setup for push, erasing 4 old simulators. |
| 2026-11-03 | Rami's choices built on branch `work/choices-followup` (not merged): "Sent" instead of "Delivered"; in a WhatsApp chat Edit hides after 15 minutes and Delete after 48 hours (mautrix-whatsapp declares both; other networks keep no limit); "·" in the info subtitle; a deleted chat that comes back shows only the messages after the delete (it showed its whole history: the delete's time now stays in the chats account data event as `cleared`); our own message brings an archived chat back, a muted one too (an unmuted one already came back). Exact feedback: one new finding (no unit test for a contract `fn`) and new evidence for a known one. |
| 2026-11-03 | B18 merged: search all chats from the bottom bar (field and close in the app's glass bar; recent chats and searches; Images, Videos, Links, Files; results in the order chats, messages, links; a hit opens its chat at the message). A local, encrypted search index (key in the Keychain). Exact feedback 77 to 82. |
| 2026-11-03 | B19 built: search in one chat from its info page's Search, which turns the page into it in place (as Beeper's). Words come from the search index, kept to the chat; Images, Videos, Links, Files and Audio come from timelines of the chat filtered by message type, so a photo, file or voice message is found by its type, not its file name. Exact feedback in its diary entry. |
| 2026-11-03 | B14 and B15's media criteria built: swipe to reply on photos, videos, stickers and files, and Copy for a photo (a PNG, through Exact's `@exact/clipboard`). The failing frequent-emoji test is fixed in its own conversation (branch `fix/frequent-emoji-test`). Exact feedback 87 to 91; the 2026-11-03 send (17 entries) is recorded in the feedback README. |
| 2026-11-03 | B13 Send Later built (Rami's OK for delayed events, 1-year maximum, on the server through the playbook on `server/phase-0`). Hold Send for set times or a picked one; the message waits on Synapse (MSC4140) and goes with the phone off; a chat bar and a list (filter sheet row) with Send Now, Change Time, Cancel. Not in end-to-end encrypted chats (a delayed event cannot be encrypted). The WhatsApp check on `@rami` passed (13:14, with no device signed in). Exact feedback 93 to 95. |
| 2026-11-03 | B12 built: GIFs from KLIPY in the + panel ("Search KLIPY"): trending, then a search after a pause; a tap sends KLIPY's largest GIF under 4 MB as an animated image; animated GIFs play in the chat. The app key comes from the Keychain at build (`scripts/setup-klipy-key.sh`). Still to check: a GIF sent from the app plays in WhatsApp (needs Rami's account and OK). Exact feedback 92. |
| 2026-11-03 | Fixed the failing MatrixCore test `testFrequentEmojisCountReactionsAndReset`: the frequent-emoji counts were right; the test took reactions back while the sdk was still sending them, and the server's copy showed again for about a second. The test now waits for each reaction to be on the server; MatrixCore counts a reaction from the sdk's answer. Details in `tasks/todo.md` (B19, "Known failing test"). |
| 2026-11-03 | B15's last criterion built: the jump button counts the unread messages below the view (it falls as you scroll), and the "New" line shows when the first unread message is further back than the first page (the chat pages back to the read receipt). |
| 2026-11-03 | M0 rechecked with 7 days of data (read only), and the server branch `server/phase-0` merged into `main` (it held M0's close, the backup, Instagram, LinkedIn and delayed events). Both directions work: 99.6% of WhatsApp messages arrive within 10 s; all 6 messages sent from Matrix reached WhatsApp. No logout; 24 websocket drops in the bridge's journald log, with no sign of a gap in messages after any of them. CPU p95 4%, memory p95 14%: under all three of Oracle's idle limits, whose scope for Pay As You Go is still not confirmed. Backups run and are intact, but on the same disk. B6: a pin in our app cannot reach WhatsApp (Synapse sends no account data to bridges). B2 and P3.3 prepared on branches, not applied. |
| 2026-11-03 | Exact gaps: four pull requests to exact2, each reproduced in a minimal app first: #1406 (B9: a drive can already edge-swipe with `tap root drag 320 0 from 2 <y>`; the refusal now names it), #1407 (B1: a labelled image counts in its link's spoken name), #1410 (B21: a large title opens when a route with no bar gets one), #1411 (T2.8: a loading or start line is a marker item put first by a `derive`). No PR: finding 19 (not reproduced), 35 and 50 (design questions for the Exact team). New findings 97 to 101. |
| 2026-11-03 | L1 built ("Later"): Camera in the + panel. A full-screen camera (`@exact/camera` over `@exact/media-capture`) with Flash and Switch Camera; the shutter's photo joins the tray as a picked photo and goes with Send. Photos only: Exact has no video recording (a native module would be needed; not asked for). Proved on the Simulator with the agent's camera as `@test1` (a photo with its caption sent); the real camera needs Rami's iPhone (`tasks/todo.md`, L1). Exact findings 102 to 105. |
| 2026-11-03 | T2.6: the recovery key opens the account's key backup in Settings (Encryption), so a new device reads older encrypted messages. Proposed for Rami: end-to-bridge encryption stays off (todo.md T2.6 gives why). |
| 2026-11-03 | T2.8 done: a row above the oldest loaded message shows a small spinner while older messages load and "Start of the chat" at the room's first message (one more row of the transcript's list, Exact finding 20). Fixed with it: a chat that opens at its "New" line never loaded older messages (the list asked once, while the line was placed). B9 done: a real edge swipe over the messages goes back with no reply started. |
| 2026-11-03 | Transcribe built ("Later"): a voice message's long-press Transcribe, on the iPhone with Apple's recognizer; the text shows under it and is kept. Rami checks one real voice note on his iPhone. |
| 2026-11-03 | Rami on M0's, B2's and P3.3's questions: "do whatever you think is best". Applied: a daily pull of the dumps, media and signing key to the Mac (`server/pull-backup.sh`, launchd; no cost); the Instagram bridge back to warn; B2 with all three suffixes removed (the app shows each network as a logo, B1); the two unused Instagram images and our build's cache deleted by hand, because the playbook's prune tools would also delete other projects' stopped containers on the machine. Sygnal installs when P3.0 is done. Details: `server/notes/install.md`. |
| 2026-11-03 | B2 done: a read-only drive on `@rami` saw 0 WhatsApp suffixes in 189 chats; Instagram names change on each contact's next update. The drive found two app bugs (todo.md, B2): a group whose newest events are all member events opens empty on a new device, and a preview shows a raw user ID as sender. |
| 2026-11-03 | Remind Me built (B7, B20, "Later"): a reminder to answer a chat, from the long-press menu or the info page's More, with Send Later's times (`LaterSheet`). Kept in the account's data (`com.ramimaalouf.multiplexer.reminders`), so other devices see it; this iPhone notifies "Reply to <chat>" at the time (`@exact/notifications`), and a tap opens the chat. The filter sheet's Reminders row lists the chats until you answer or clear. |
| 2026-11-03 | Bookmarks built (B14's menu row, one list from the filter sheet, the info page's row, B19's kind). Storage decision: one global account data event, `com.ramimaalouf.multiplexer.bookmarks`, as the names only you see. Matrix has no bookmarks, and the SDK cannot write custom room account data. Account data reaches only the account's own devices: Synapse 1.164.0 sends a bridge room events, receipts and typing, to-device messages, key counts and device lists, never account data (checked on our server, read only), so no bookmark reaches WhatsApp. Each bookmark keeps the chat, the event, the sender, the text (500 characters at most) and the kind, so the list shows without opening a chat; an edit or delete later does not change it. Fixed on the way: a crash at launch when several parts started the sync at once. |
| 2026-11-03 | Merge Chats designed, not built (todo.md "Later", plan Q6): Beeper's feature read from its help page; a merge kept in account data is sound with Matrix; a switchable chat is recommended over Beeper's combined timeline, which would make every message action follow its own network. Waits on Rami. |
| 2026-11-03 | Message expiry built (the last "Later" item): the info page's Disappearing Messages row sets WhatsApp's timer through the bridge's room state. Also fixed: a chat whose newest events are mostly hidden (tonight's renames) opened empty; it now pages back to its messages. |
| 2026-11-03 | B22 Select Chats done: the title menu starts selection; a chat's long press starts with that chat selected. Rows and pinned pictures share selection marks. Archive or Unarchive, read status, mute, priority, pin and Delete act on every chosen chat. A pending spinner disables edits; success ends selection; failure keeps it and offers retry. The title is opaque so scrolled chat text cannot show through. Proved by two-device MatrixCore testing and iOS drives, with light, dark and the largest text size checked. The previously queued merged timeline suite passed 21 enabled tests, with one intentional skip and no failures. Labels remains next. |
| 2026-11-03 | Push without P3.0, on the Simulator "MX main" (branch `work/push-prep`). MatrixCore: `PushContent` and `MatrixPush.content` (the extension's memory-constrained client on the app's store, lock `notifications`; the app's client takes it as `app`), and `setPusher`, `deletePusher`, `pushers()`. A multi-process lock needs session delegates: `SessionStorage`, backed by the session's Keychain item. `testAPushShowsTheSenderAndTheText` as `@test1` and `@test2`: the extension's client read the message in 2.35 s (plain room) and 2.76 s (encrypted room) while the app's client ran on the same store. The app asks for notifications after sign-in (and Settings has "Turn On"), gets a sandbox token through callbacks added to Exact's app delegate at run time, and sets the pusher (`...ios.dev`, `event_id_only`, Sygnal's URL; our server takes it with no gateway yet); Sign Out deletes it. `scripts/add-notification-extension.sh` adds the extension (73 MB, MatrixCore and the sdk inside) and the push entitlements after Exact's build. `simctl push` runs no extension, but the Simulator has a real sandbox token, so `scripts/send-test-push.sh` with P3.0's key can prove the extension on the Simulator before the iPhone. The App Group store move is planned (`matrix-core/NOTES.md`), not done. Exact feedback 117 and 118. |
| 2026-11-03 | Merge Chats: Way A, the switchable chat (one row; network tabs in the chat bar; the default network kept with the merge, so it follows the account). Decided by the coordinator under Rami's "continue as you see fit"; Rami may override (B, Beeper's combined timeline, was the alternative). Q6 answered so. |
| 2026-11-04 | B14's open risk closed (branch `work/account-data-safety`): every change of the account's own data (names, archive and delete marks, reminders, frequent emojis, bookmarks) starts from the store's event, else the server's, and throws if that read fails (`AccountData.swift`). The test failed before the fix only for a change made before the first sync (an emoji count); right after the first sync the store already had the data. Another device's bookmark now reaches the list in about 2 s through the account's data watch (also reminders); the minute's reload is gone. P3.6's first criterion checked without APNs: Synapse's own `GET /notifications` shows a muted chat notifies nothing, a bridge's mentions-only chat only mentions, a normal chat everything (`PushRulesTests`); our mute already does this. Also fixed on the push branch: a deleted chat hides every message its open timeline shows. |
| 2026-11-04 | The frequent-emoji test failed again, also on `main`, for a new cause: the sdk can replace a timeline item under a new id while the event stays the same (a message went from id 40 to 47), and `toggleReaction` returned silently for an id it could not find. The app had the same bug: a reaction tap could do nothing. `TimelineItems` now remembers each id's event and finds a replaced item by it; a message truly gone throws `MatrixCoreError.noMessage`. 3 failures in 3 runs before, 3 passes in a row after (branch `work/emoji-test`). |
| 2026-11-04 | UI faults, worst first: the chat bar fixed in the app (its backdrop sized by the bar, so no message shows behind the name); `check` is clean on it only with a local exact2 branch (`local/check-hidden-by`, not pushed) that tells the iOS host's check which opaque views cover an item. B3: the app draws the edge effect under the bottom bar. B4: no longer seen. B21: still open after three tries (trace in todo.md). |
| 2026-11-04 | Health check of `main` after five merges (branch `work/main-health`): the whole MatrixCore suite, one class at a time with the lock let go between classes (load 2 to 10, one spike to 27): 74 passed, 2 failed, none on the first sync. `VoiceTests.testAVoiceNoteReachesTheOtherWithItsLengthAndWaveform`: a test bug; it found the received note by length and size, which an earlier run's note shares (the same recording), and the newest match could be that note while this one was on its way; it now finds it by event id (2 of 2 after). `NetworkFilterTests.testTheNetworkFilterNarrowsTheListAndThePinsAlsoUnderUnread`: the test process was killed from outside ("signal kill") after 50 s, no assertion failed and no crash report; not reproduced in 3 runs. `test ios` 6 passed; `verify ios` clean. |
| 2026-11-04 | UI review resumed in work/polish (multiplexer-older; T3 binding remains detached work-exact-gaps). Select Chats explicitly speaks bridge networks; Settings Notifications wraps at largest text. Sender wrapping transferred to Later. Normal Exact ed43ad09a0 verification: 6 tests passed, light/dark checks clean, eight largest-text screens without overflow. Finding 49 remains open; local befb32d3cd experiment preserved, not required for app fixes. |
| 2026-11-04 | Integrated work/polish commits 7e05b02 and c56f5a2 into main. App changes match the UI lane’s verified files; retained the health-check history and coordinator assignments. Sender preview wrapping stays pending in Later; no local Exact experiment is included. |
| 2026-11-04 | Push readiness: duplicate Labels preserved on work/labels-finish at c2c72da and handed to its sole owner. Shared-store preparation committed as 0939ebc: optional session location, recoverable directory move before SDK restore, in-place Keychain updates, agent isolation and per-session deletion. Filesystem tests 11 passed; push/search/sign-out regression selection 15 passed; pre-integration verify ios clean (6 tests). Entitled migration and physical push remain blocked on P3.0. Main cebda48 incorporated in 0fbdf15, preserving Settings notification wrapping; integrated verify ios passed 6 tests, light/dark checks and 8 largest-text screens (75.2 s). Only existing Exact finding 1 received evidence; no new allocation or feedback send. |
| 2026-11-04 | Integrated push readiness head 86d3a80 into main with no code conflicts; refreshed the app’s MatrixCore copies. Missing legacy data without an available App Group remains conservatively unavailable: session metadata is retained and replacement login is refused until recovery, rather than risking a store moved before metadata persisted. Entitled migration and locked-phone delivery remain unverified. |
| 2026-11-03 | L2 built: the filter sheet lists the account's spaces after the networks (14 WhatsApp communities on `@rami`, read only), without each bridge's own space; choosing one narrows the list. L3: Requests (Matrix invites, with Accept and Decline) built; a network's message request is not an invite and waits for one to look at; New Space asks Rami (a Matrix space, the same as Labels, or none). Fixed on the way: two sources asked at once at launch each started the sync and crashed the sdk's room list. |
| 2026-11-04 | L3 New Space: coordinator approved a private Matrix space. Built required name and optional picture, empty spaces in filters, and chat membership from the menu or info page. Core community/Requests tests passed 8/8; iOS verification passed 7 tests with no findings. A review found and fixed a late completion navigating away after dismissal; the callback belongs to its initiating route entry. Space-only sync changes refresh the list too. |
| 2026-11-04 | Later ready for serialized integration: tested code head `1a38b7c` incorporates main `03fec0f` and UI main `cebda48`. New Space `149843c`; room-member preview resolution and fallback wrapping `dc70b9a`; merged-space compatibility `840eea5`. Ten existing focused core tests and both corrected compatibility tests passed; the latter proves new children survive a later failure and retry completes membership. Final `verify ios`: 7 tests, no findings, 9 largest-text screens. Signed-in Select Chats fallback wraps in both appearances at largest text; account signed out and own simulator shut down. Prior real-account 29-to-zero raw-sender evidence retained; no new real-account drive. Main `316e116` arrived during verification and is deliberately left for coordinator integration, preserving push/shared-store migration. No main merge by this lane. |
| 2026-11-04 | Integrated the complete Later branch e93aa0e with main 316e116, preserving shared-store migration. Combined verify ios: 7 passed, light/dark clean, 9 largest-text screens without overflow (186.9 s). Combined MatrixCore selection: 25 passed, 0 failed/skipped (224.2 s), covering communities, Requests, preview senders, push and session stores under the shared lock. Labels remains outside this integration pending review fixes. |
| 2026-11-04 | Integrated full Labels branch 2b55caf after the combined 39-test selection passed on main under the shared lock (no failures/skips, 1062.9 s). Preserved all earlier UI, Spaces, Requests and session-migration work. Contract build clean; app/core code identical to the lane’s final 9-test iOS verification, with light/dark and 11 largest-text screens clean. The archive fix changes only test event sequencing. Feedback remains local per Rami. |
| 2026-11-08 | D12: an agent CLI, `mx` (Swift, MatrixCore, macOS SDK built by us). C0 passed as `@test1`: sign in, chats (fresh, 0.3 to 0.5 s warm), parallel calls, sign out removed the device. A cold first run lists chats before the server's order arrives (not by recency); warm runs are in order. |
| 2026-11-07 | R04 changed for chats with no kept copy (branch `fix/demo-bugs`): such a chat now waits for its full first screen under the loading spinner, instead of answering on the timeline's first diff. Why: on a new device that diff holds only the newest message, which showed alone for about 0.35 s and then jumped up (seen in the demo recording). A chat with a kept copy keeps R04's early answer, since the copy covers the older rows. The older-messages row keeps one height in both states. The demo staging seats a third contact in its group: its bot is listed but never joins, so the app's member count (which subtracts listed service members, right for real bridges) read the group as a DM. |
| 2026-11-07 | DMs or Groups for a bridged chat (branch `fix/members-composer-groups`): `m.direct` decides first; a bridged room not marked direct with at most 2 people besides its bot is what its bridge's `m.bridge` says (`com.beeper.room_type` `dm`, else a group), read once per room from the server and kept; with no bridge state the count decides, as before. Why: the count cannot tell a group with one other person from a DM. A read-only audit of the real account (349 rooms) found every bridged DM in `m.direct` with room type `dm` and no bridged group there, so only a few rooms are asked. Also: the info page counts a service member out only when it has joined (the list's rule), and the chat's composer shows from its first frame. |

### Appearance preference (2026-11-04)

Accent is a local persisted root setting, alongside playback speed. No account data or network
write is used. The exact six-digit sRGB fill is retained for outgoing bubbles and badges;
black or white foreground is selected by contrast. The app computes readable light/dark
control tints separately. The native iOS picker edits a draft: Cancel discards it, Use Color
commits it. Default/reset is blue (`#007aff`). Native tests and verify pass, but app-wide
acceptance remains open for the separately owned framework navigation-root tint defect.

Navigation tint follow-up: local finding 125 records the stale prominent header.
The logical-root candidate passed 19 host tests, but a rebuilt app still showed a blue
native Sign In button for persisted yellow in a cold light-mode DISPLAY capture. One dark
capture showed yellow with black text. A later host fixture initially failed because its
encoded color pair was malformed; corrected decoding preconditions and the valid pair pass
20/20 tests. That fixture does not reproduce the native pixel failure. A development-only
observer now reproduces the blue capsule in DISPLAY while root, window and navigation bar
all resolve the intended brown tint. Its traversal regression passed 3/3 host tests and the
driver control passed 16 assertions. Capture bracketing was stable, but public UIButton
configuration and unique item association were unavailable, so the specific native paint
cause remains unproved. An earlier brown capture remains negative reproduction evidence.
The retained-item prominent tint candidate now passes 43 focused host tests on iOS 26.5
(nine navigation lifecycle, 20 AppAccent, 14 BarFace; no skips). Earlier two failures were
strict RGB reads of unset test-window baselines before ownership operations; explicit dynamic
baselines plus a separate nil-restoration control passed. A test callback's off-main layer read
was corrected separately. Production QoS reports have no measured stall diagnosis yet.
Native DISPLAY fill/foreground acceptance and pre-26 execution remain open.
`exact2-navigation` remains frozen at `7529006ab9`.
The test-owned main-thread violation is corrected and AppAccent 20/20 passes without that
warning. Candidate native cold yellow/light and mounted orange/light captures are positive.
A reset capture after an unexpected system Save Password prompt shows qualitatively cyan
label ink rather than expected white. Native enabled/highlighted/dimming state at capture
was not recorded, so cause remains open. Dark and remaining navigation cases are unproved.
Three foreground reset controls now pass in the supported scene-bearing ExactTestHost
(3/3, no skips, iOS 26.5): no alert, completed alert, and disabled-alert/re-enable. Active
scene/window, presentation/dismissal, dimmed/restored mode and strict foreground properties
were exercised. The earlier bare-runner attempt failed presentation setup, not foreground
assertions. Hosted logs retain 38 selected-state UIKit warnings; no cause is assigned.
Public-property success does not resolve the native cyan pixels. The next native control
reproduced cyan-looking reset text without an observed alert, through a documented
disable/re-enable sequence. Enabled brackets passed; exact native state and cause remain
unproved. A premature cleanup notice was corrected before handoff, then no-opener/process/
shutdown checks and owner release completed. The next observation reuses the existing gated
diagnostic in the same binary to separate item attributes, public button facts and pixels.

Current validation limits: the shared-public-API unread control failed on unchanged
`a09a33d` (23/25) and the cache branch (19/25), with every sent event present on the
server and the reader's receipt still at its pre-batch anchor. The SDK contains an
upstream gappy-sync recount regression compatible with this behavior, but the executed
pipeline is not established. The isolated selected-room subscription pair passed all eight
cases, including its control, so it established neither a fix nor subscription necessity.
Historical cache native evidence showed an available row at 11 ms and source reply at 68 ms,
with cached content visible during the push. Video and source clocks do not establish an
absolute tap-to-row time. A fresh review then found four lifecycle defects: deferred older
work after reset, late unread positioning after search, empty-budget retry and final-page
delivery ordering. Three corrections are drafted; the fourth needs a sound SDK delivery
boundary. Neither TimelineStart, Idle nor a fresh listener snapshot proves pending cache
events reached Swift. Current source is unaccepted; old measurements remain historical.
Focused correction validation now includes two passing controlled core tests and eight passing
pure Contract fixture tests on a genuine development build. Separate timer controls passed
three cases and reproduced replacement-placement expiry at the old visit's deadline: at the
authored 801 probe, placing was false although the replacement deadline was 902. All production
inputs remained unchanged. Later failed-case assertions advanced mutation ticks, so no
absolute later send timing is inferred. The reviewed placement-operation correction now
passes all 16 controls: original eight, unchanged four timer regressions, and four new
same-visit/repeated-event/late-unread/readiness-reset controls (329 compiled steps). The prior
replacement RED is green. Authored boundaries verify queue retention, one deferred send and
no duplicate. The current producer emits no warnings; historical nested-read diagnostics
remain recorded, with no broader native/search acceptance inferred. Real search/navigation,
final-page delivery and deep-unread checks remain open.
Inbox's compact header failed native scroll inspection because
its material starts below the status band; a route/scroller-local paint-only extension is
being implemented in isolated source only. The proposed `backgroundExtend="safe-area-top"`
affects decorative material and solid backing, not layout or hit bounds; it is unbuilt and
not consumer-ready. No guessed inset or global viewport change is used.
Source resumption confirmed only schema/lowering/compiler-test scaffolding exists; no host
paint or lifecycle implementation has been validated. The next authorized source slice is
logical owner/clip/edge resolution with lifecycle fixtures on the tested framework base.
Material/solid projection, native display proof and inbox adoption remain later gates.
The full-root cached-search harness source is checkpointed at `cb97600` after two scoped
reviews. Its first producer-only attempt staged successfully, then composition rejected a
declared environment key absent from the wrapper entry point's static reads. No producer or
browser control ran. Cleanup verified owned descendants/openers and released the slot.
Source tracing confirmed Exact transforms environment reads only in root `app.ts`; imported
modules reject remaining reads. Failed-attempt evidence is preserved in lane docs commit
`0b95198`. A narrow test-artifact boundary is now authorized in source: retain and hash the
byte-identical production input, then use the pinned official `inlineSettings` transform with
an explicit empty synthetic key and a fresh descriptor directory without environment files.
The wrapper must enforce the same synthetic value, and later genuine producer settings must
agree with the transformation record. No manual replacement or unused dummy read is accepted.
This revises executable-byte equality to verified official-transform equality; it does not
change production code. Source review precedes any new staging, producer or browser run.
Environment correction `cb43e9f` now passes its separate bounded validation: 12 exact
environment controls, fresh staging, composition/TypeScript, normal development producer,
official artifact equality and actual compiled grant normalization. Normal Exact `ed43ad09`
and pinned Rolldown 1.2.9 remain this harness's toolchain, separate from root's native `d0d66b1`.
All 650 actual producer inputs match before/after; genuine receipt `76cd8545` and 285-file
bundle manifest `1959ec21` are frozen. Seventeen producer warnings remain recorded. Cleanup
released the scheduling lock at 07:09:41 UTC after process/openers/source checks. The three
browser cases now have a separate bounded handoff; they are not yet reported passed.
Coordinator initially compared the genuine receipt hash against its reformatted JSON copy
and incorrectly sent a handoff after that check failed. Launch was immediately held. Corrected
checks verified the genuine file, parsed copy equality, full bundle and cleanup before reissue;
the lane must confirm no prior launch. This was a coordinator validation-path error, not a
producer defect. Preserve `tasks/evidence/cache-environment-producer-validation.json`.
The first browser case then stopped during setup: the captured module URL correctly used
`/.exact/gen/<generation>/modules/index.js`, but the harness asserted `/modules/index.js`.
No controller connection or search/placement assertion ran; the other two cases were unstarted.
Cleanup released resources at 07:24:17 UTC with no source/product changes. A final bounded
source-only correction may validate the captured initial URL against the producer generation
and origin, retaining its identity. No further producer/browser run is authorized in this window.
The background owner resolver is frozen at source round 2 after attachment, equal-cover
reparenting and fixture corrections. Scoped review remains pending; applied geometry must be
acknowledged after deferred cover application, not inferred from cached cover values. No
material/solid projection or consumer readiness follows from this source slice.

Capacity recovery: builds stopped at ENOSPC with less than 200 MiB available. A fresh
check later found about 69 GiB free without coordinator deletion; the cause is not attributed.
The rejected `rm -rf` incremental-cache cleanup was not retried. Runtime and heavy build
windows remain serialized, with fresh capacity checks before resuming.

### Coordinator checkpoint (2026-11-05)

The prominent-item candidate now completes its bounded native appearance/Settings matrix.
The coordinator inspected dark-white, light-black and reset DISPLAY captures plus partial
and settled Settings edge-gesture frames. Dark-yellow proof is retained from the earlier run;
R3 selected white and black through the real picker with fresh display-to-point geometry and
exact saved-color gates. Plain native Back, one visibly cancelled edge and one completed edge
passed. Candidate executable `1ee10e7f` and four-file framework patch `3d944845` stayed unchanged.
The lane's durable receipt is `multiplexer-older` commit `c0f34f18`, file
`docs/exact-feedback/proposals/prominent-native-r3-receipt.md`. Product-only commit preparation
is authorized; framework integration and combined-app validation are still pending.
The product-only framework commit is now `40bafa7e`, directly atop row-cancellation fix
`7529006`. Coordinator independently verified its complete diff hash equals tested `3d944845`.
Regression routing remains a separate source-only follow-up: move extension tests into the
declaring class and mark the three scene-dependent entries for the supported hosted runner.
Diagnostics and the interactive UIKit visual reference remain excluded from the product commit.
Regression commit `d0d66b1` now follows `40bafa7e`; its complete two-file diff matches the
validated patch `a6be089d`. Reorganized tests passed 43 bare and three hosted cases separately,
with no failures or skips on iOS 26.5. QoS and selected-state warnings remain recorded; both
runs had no Main Thread Checker reports. The coordinator created clean framework worktree
`/Users/rami/Documents/code/exact/exact2-multiplexer-integration` at this head. Root app paths
remain unchanged: supported `update` also runs the Contract formatter/compiler, so dependency
refresh belongs to the next guarded integration build window, not source-only preparation.
That dependency integration now passed: official `update` changed six generated path/schema
files only, then the Contract/TypeScript gate returned `[]`. The new framework's declared Bun
dependencies were installed with the frozen lock; its tracked sources remain clean. App package
paths still use the normal checkout's identical package tree, and all 30 native MatrixCore copies
match canonical sources. Preserve the initial documentation-symlink preflight failure and stopped
gate before dependency setup. Receipt: `tasks/evidence/framework-dependency-integration.json`.
A fresh native build and combined-app verification now passed at app `6a333a41` with
framework `d0d66b1`. The no-install build took 383.132 seconds; its roster probe briefly
booted only MX main, then shut it down, with no app installation during that build.
Executable `88cdd9c2` and complete bundle manifest `8664c4c4` were verified before runtime
and after installation. Native verify passed all 12 authored tests in 122.8 seconds and
reported no findings on light/dark checks or spill across 14 body-53 screens. The coordinator
inspected saved light, dark and appearance screens. A later direct Device capture showed
SpringBoard because verify had closed the app; it supplies no additional live app proof.
The separate symbolic verifier delivered three scripts and skipped nine unsupported scripts;
that limitation is distinct from the 12 native test passes. Lean semantics was unavailable.
All 99 tracked runtime processes ended, large/light was restored and read back, MX main
was confirmed Shutdown, and the owner-checked scheduling lock was released at 06:56:39 UTC.
Receipt: `tasks/evidence/framework-integrated-native-validation.json`. This closes the bounded
dependency/build/auth-free integration check, not authenticated chat, status-band or cache proof.

Reset blue retains pale cyan/light native text. The existing observer recorded correct white
normal title attributes, and a UIKit-only hosted reference reproduced the qualitative hue
without Exact projection objects. Readable polarity passed the bounded matrix; neither literal
white raster output nor numerical contrast is certified. PNG transfer metadata is unspecified.
This evidence does not close intermittent authenticated chat corruption, pre-26 execution,
symbol/highlight/focus behavior, or the inbox status-band/material work. R3 cleanup first blocked
release while the simulator still reported Booted, then confirmed Shutdown and every owner/process
check before releasing. No premature handoff occurred in that run.

Cache placement is preserved as local checkpoints `6cf4151` and dependent `63c5d6e`.
The latter's 16 passing controls do not make its unfinished foundation merge-ready. Full real
search/navigation harness work is source-only; final-page delivery and deep unread remain open.

Bounded receipt capture at isolated `d7028a98` compiled successfully. Its first exact test
passed, but the runner rejected interleaved DEBUG output because it expected the test name and
`ok` on one line. The run stopped: 18 tests did not start. Preserve the raw failed runner receipt
and separate log-based first-test result. Matcher-only correction with offline parser controls
is authorized, without product edits or rerunning the passing test. Capture composition,
session revocation, FFI copy bounds and app integration remain unproved.
Continuation result: matcher correction `73a336e` passed eight offline parser fixtures.
The 18 unstarted selectors then passed once using the unchanged binary directly, with no
Cargo invocation. Together with the preserved first pass, all 19 distinct capture tests pass
on `d7028a98` / binary `91f1ab5f`; the original failed runner receipt remains unchanged.
Owned processes ended and target-openers checks passed. This validates the admitted Rust
capture subset, not allocator/latency bounds, FFI copies, session ownership or composition.
The next source-only plan maps exact-identity composition against the tested state primitives.
That source plan (`d9c68261`) passed five independent document-review lenses without findings.
The isolated Rust-only composition unit is authorized in source: shared operation budgets,
exact captured preview plus revision-checked eligibility, and terminal private session acceptance.
No build, FFI export, native lifecycle hook, advanced ordering or app integration is authorized
by this step. Implementation requires its own source review and later validation window.
Implementation `57fac7b5` passed the second scoped source review after test-only guard and
qualifying-envelope corrections. A separate bounded host window is now authorized against
manifest `a3247a4d`: one offline compile, then 31 exact direct-binary tests once if compilation
succeeds. Historical state/capture binaries must be preserved first. Stop on the first failure;
1200 seconds of work plus 120 seconds of cleanup must fit before the user's wind-down.
This is execution authorization, not a result. Pending timer expiry, actual gate contention,
SQLite composition, FFI and native lifecycle remain outside the selected proof.
Host result: the one compile and all 31 exact selectors passed on `57fac7b5`, binary
`3020ad05`, with no retry or ignored test. All owned groups ended and target-openers check
passed. The proposed managed-owner/foreign-transfer plan remains unaccepted; a custom string
packet versus bounded typed record needs an explicit design decision before implementation.
