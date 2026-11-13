surfaces: ios, macos
agent: codex, gpt-6-astra
task: adapt a template's composer-to-message animation to an asynchronous chat timeline

### Rough
- adapting template motion required reading its frame loop and bubble implementation (about 20 minutes). the chat-thread recipe covers scrolling after send but not the composer handoff. a documented animation recipe with asynchronous message identity would help.

- the first native build compiled Rust, then failed with `compiler input has no captured source identity: .../packages/child-process/exact.json` through a framework symlink (about 3 minutes). an environment override alone did not fix it; running `update` with the canonical absolute EXACT2 path did; the tool should canonicalize the framework path or explain the mismatch.

- `frame("composer")` used the authored position of a keyboard toolbar, even though native layout reported its lifted position (roughly 276 points apart). this made the copy start under the keyboard. about 45 minutes tracing and recording, including native route/content inset alignment; a session-scoped native geometry read at send adapts the app. frame() should include the keyboard toolbar's native lift, as its viewport-space documentation promises.

- geometry guards needed another source read (about 5 minutes): a route stays provisional while any descendant image has no natural size. the send origin only needs the route position, so waiting on that flag unnecessarily skipped motion. documentation should distinguish uncertain content size from a usable positioned ancestor.

### Lean in
- frame geometry, spring transitions, and a frame task express the template's motion without changing the framework.
- contract diagnostics named the unsupported dynamic scroll behavior and supplied the accepted values.

### Needed
- keyboard geometry: by hand, a native read of the displayed composer at send

### Checkpoints
- editing app.contract / app.ts: rough, see the template adaptation above
- iOS build: rough, see canonical framework paths above; subsequent incremental builds reused native modules
- native drives: smooth after geometry adaptation; inspected short text, multiline replies, rapid sends, navigation, reduced motion and off-bottom sends
- native verification: smooth, 14 tests and light/dark plus 16 largest-text screens clean
- feedback: local only; no diary, command logs or attachments sent
