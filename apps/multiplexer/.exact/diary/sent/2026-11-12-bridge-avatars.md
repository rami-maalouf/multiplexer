surfaces: ios
agent: codex
task: restore profile images in bridged direct chats

### Rough
- copied a previous build target with filesystem clones to reuse native compilation. the build refused with `no matching rustc unit dep-info for unicode_ident`, identified a different original target path, and requested deletion/rebuild. about one minute plus the rebuild. restarting with the official fresh cache seeding; relocatable app build caches would remove this cost.

### Lean in
- the existing native data boundary allowed one avatar resolver to serve the inbox, chat info and downloads.

### Needed
- profile images: provided through the native module.

### Checkpoints
- iOS build: rough (relocated target rejection above)

- driving the app: smooth; the picture rendered through existing image views.
- iOS verification: smooth; authored tests, both appearances and largest text passed.
