surfaces: ios
agent: codex gpt-6-astra
task: open the intended conversation from a remote notification

### Rough
- a live tap reached the host but logged `@exact/notifications.notificationclick: no handler hears it`. the native event identity uses the package's short registered name, while its manifest and imports use the scoped package name. the receiver-only test could not catch this downstream mismatch. tracing the runner and inspecting the unified journal took about ten minutes; a documented payload constructor or a contract-level tap fixture would make this boundary explicit.
- remote notification clicks are silently discarded unless their userInfo includes the host's internal activation entry. tracing the notification receiver and cross-process session selection took about ten minutes. the local-notification api documents the event, but a remote service extension has no documented constructor for its activation entry. a public remote activation adapter would remove the need to depend on this private payload shape.

### Lean in
- the host already queues activation events until initial data and the first draw are ready, and deduplicates scene and delegate callbacks.

### Needed
- notifications: missing documented remote activation metadata construction.

### Checkpoints
- native reproduction: a simulated remote notification opened the previous screen instead of its conversation.
- receiver probe: the actual native receiver compiled with minimal session doubles reproduced the missing destination event.
- implementation: the maintainer approved the pinned activation entry with regression tests; the native receiver and fallback tests pass.
- smooth: actual sandbox notification taps reached the existing handler in warm and terminated-app launches; the runtime module name is `notifications`.
