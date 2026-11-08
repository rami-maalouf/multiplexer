surfaces: ios
agent: codex gpt-6.1-sol
task: validate and prepare a native app for store distribution

### Rough

- archive push registration: inspecting the archive pipeline and framework source
  showed that a live-activity refusal scans every store archive for ordinary push
  registration, even when the app has no live activities. About 5 minutes tracing
  the call and its existing test. A focused framework fix is being prepared; no
  bypass or encoded selector was added. Scope the refusal to the feature it governs.
- extension packaging: the framework does not package a custom notification service
  extension or its shared entitlements. An app-owned post-build packaging helper
  needs a separate store mode, in addition to its development-device mode. Existing
  finding 113 covers this cost; artifact validation remains pending.
- worktree package paths: the supported update refreshed the framework's generated
  paths but left the app's file dependencies pointing at the original checkout depth.
  The compiler then named an uninstalled clipboard package. About 2 minutes; installed
  the same pinned local packages with absolute paths through Bun for this worktree.
  These local path changes are excluded from publication. Existing checkout-depth
  feedback applies; update should refresh all of its local dependency paths together.

### Lean in

- the existing native test and build receipts make candidate provenance inspectable.

### Needed

- remote notifications: by hand (native callbacks and archive entitlements)
- notification service extension: by hand (post-build packaging)

### Checkpoints

- deploy: rough, archive push registration and extension packaging above; not yet complete
- packaging: app-owned TestFlight helper now has a store mode for the notification
  extension and production push entitlements (`90736ae`); gateway config accepts a
  separate production app id (`7fcb305`); controlled invalid-token probes reached
  APNs in both environments
- RoomKinds: failed bridged-kind lookups can be retried; 6 unit tests pass
- R03: read-only phone inbox scroll after Home/reopen did not freeze under
  automation on the signed-in orbit build; R03 stays open until a finger proof
