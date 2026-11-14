surfaces: ios
agent: codex gpt-6-astra
task: remove delivered notifications when their conversation opens

### Rough
- a worktree build compiled through its relative framework path while the launcher selected the canonical path, then refused with `compiler input has no captured source identity` for a package manifest. the build spent about a minute before naming the missing identity. regenerating integration paths is the next step; a preflight that checks the two framework identities would avoid the late failure.
- regeneration alone then exposed mixed cached rust crate identities through the two paths (`expected exact_markdown::style::Styled, found Styled`). returning to the relative path still failed capture. using canonical integration and package paths with an isolated cargo target avoids mixing the old compiler artifacts. source tracing and rebuild attempts cost about five minutes; canonicalized dependency identities would make worktree builds less fragile.
- the notification package closes a known request identifier, but remote notifications have system identifiers. checking its native implementation took about two minutes. the app needs a native delivered-notification query and selective removal; a documented group or metadata-based removal operation would avoid that bridge.

### Lean in
- a resource can follow the visible conversation independently of network-backed read receipts.

### Needed
- notifications: by hand, account-scoped removal of delivered remote notifications.

### Checkpoints
- reproduction: opening a conversation left its remote notification in notification center.
- validation: native selection and data-source fixtures pass; installed simulator screenshots confirm inbox opening, fresh banner taps and repeated same-conversation taps clear only the intended notifications.
- the reactive source includes the navigation visit identity so a repeated tap runs cleanup even when the conversation id stays the same.
- canonical integration and package paths with an isolated cargo target built and installed successfully; temporary path changes are excluded from the product commit.
- native verification: smooth; all 14 authored tests, light/dark checks and 16 largest-text screens passed in 144.5 seconds.
