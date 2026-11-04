surfaces: ios
agent: Codex gpt-6.1-sol
task: resolve a group preview sender through the room member when the event has no profile

### Rough
- after an in-drive light-to-dark preference switch, check claimed the title was black on black, but its screenshot showed white on black. no actual title contrast failure was visible; related to known finding 40. a fresh-appearance check is planned after integration. about 2 minutes.
- the existing native module build again compiled the unchanged vendor bindings after a small core change (known finding 1). view-only wrapping updates typechecked quickly.

### Lean in
- the drive masks sign-in fields, and a narrow state read allowed counting unresolved previews without displaying private chat contents.

### Needed
- none

### Checkpoints
- read-only baseline reproduced missing sender names; the account signed out.
- core regression test: a fresh reader sees the room member’s display name before opening a timeline; passed.
- nil, blank and whitespace member names fall back to the sender id; passed. the review finding is resolved.
- prior authorized read-only comparison: 315 chats, zero raw group senders after the fix versus 29 before; 28 matched the previous member-name snapshot and the remaining chat had a newer message. both devices signed out. no new real-account drive on restart.
- the first native list query took 2.042 s; later queries were mostly under 0.5 s.
- accepted the other ui lane’s break opportunities after colons and dots in fallback sender labels; the raw-id fixture wraps within the inbox at the largest system text size in both appearances; test device signed out.

- final pre-integration verify ios: 7 tests passed, no findings, 9 largest-text screens fit.
