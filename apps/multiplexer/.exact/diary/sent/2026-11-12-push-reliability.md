surfaces: ios
agent: codex gpt-6.1-sol
task: recover remote notification registration after transient failures

### Rough
- an isolated app worktree with EXACT2 set still failed its first ios build because generated cargo patches pointed at the original relative checkout. the error named `bun exact.mjs update`; regeneration fixed those paths but left package file dependencies uninstalled. about 5 minutes. reused the installed package copies locally. a complete worktree integration update would help.

- ordinary ios builds replace the previously packaged push-capable app with a bare bundle: no apns entitlement, app group entitlement or notification service. reproduced by inspecting a fresh build. added a complete build/package/reinstall command rather than relying on a remembered second step. about 15 minutes tracing builds and signatures. declarative remote push packaging would remove this workaround (known finding 118).
- the first isolated ios build took about 5 minutes across rust, swift modules, package arms and runtime roster probing. later native edits rebuild the bindings and roster. the public build summary made the stages visible.

### Lean in
- the cargo build refusal names the required paths and regeneration command.

### Needed
- notifications: by hand; remote token registration and recovery live in a native module.

### Checkpoints
- ios build: rough, generated paths in a worktree (above).

- driving the app: smooth for the app's authored tests, all 13 passed.
- ios build: the complete wrapper installed both simulator and physical-device builds, with separate native signing checks.
