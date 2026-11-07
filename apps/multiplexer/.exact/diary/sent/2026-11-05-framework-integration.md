surfaces: ios
agent: codex gpt-6-astra
task: prepare a tested native navigation framework stack for app integration

### Rough

- Following the generated dependency-update instruction required reading app-cli.mjs and exact.mjs to determine whether it was source-only. `update` calls `new --update`, which refreshes paths and invokes `contract fmt --uses`. About three minutes of source lookup, no update executed. Reserved the actual refresh for a guarded build window rather than assuming a new checkout has a compiler ready. A command card naming this compiler side effect would make scheduling clearer. Related path-management evidence belongs with existing finding 46; no new runtime defect claimed.

### Lean in

- Product and regression commits can be verified byte-for-byte against their tested patches and assembled in a clean worktree without carrying diagnostic hooks.

### Needed

- dependency refresh: provided; compiler side effect required source inspection before scheduling.

### Checkpoints

- framework source integration: smooth, clean checkout of tested stack.
- app dependency refresh: not executed; compiler step identified first.
- follow-up: official update passed after preserving a local preflight failure on the tracked documentation symlink. six generated dependency/schema files changed; authored contracts did not. the new checkout needed its declared bun dependencies installed with its frozen lock. an earlier type gate produced no diagnostics and was stopped after the missing installation was identified; its exact cpu-spin cause is unproven. the subsequent contract/typescript gate passed with `[]`. all 30 copied core swift sources match canonical files. native rebuild remains pending.
- final checkpoint: the integrated native build passed in 383.132 s; no-install still briefly booted the named simulator for its roster probe. native verify passed 12 authored tests in 122.8 s, with light/dark checks and 14 largest-text screens clear. saved light/dark/appearance captures were inspected; a direct device capture after verify showed springboard, so it adds no live app proof. installed executable identity matched. all owned processes ended, large/light read back, own simulator shutdown verified and owner lock released. symbolic verification's nine unsupported scripts and unavailable lean semantics remain separate limitations.
