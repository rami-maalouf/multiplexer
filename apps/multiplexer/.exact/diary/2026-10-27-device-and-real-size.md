surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: run the app on a physical iPhone, and load a real account's 254 chats on the simulator; add unread counts

### Rough
- The first `bun exact.mjs ios --device --phone <udid> --run` signed fine, then failed a minute into the Rust build: "error[E0463]: can't find crate for `core` … the `aarch64-apple-ios` target may not be installed" for each crate. The app's pinned toolchain had only the simulator target; `rustup` is not on PATH here (it is in `~/.cargo/bin`), so the fix was `~/.cargo/bin/rustup target add aarch64-apple-ios --toolchain 1.97.0`. ~3 min. What would have helped: `ios --device` (or `setup --check`) checking the pinned toolchain's iPhone target before building, and naming the command with its `--toolchain`, as it checks the signing profile first.

### Lean in
- `ios --device` checked the signing profile before building and took the team wildcard development profile for an app without widgets; the first device build took 1.5 minutes.
- `agent ios --device --phone <udid>` drove the real phone with the same steps as the simulator (type, tap, screenshot, tree), so sign-in, a relaunch and a send were checked on the device without touching it.
- A plain `list` of 254 rows passed `check`, and the room list answered in 0.24 s after a relaunch.

### Needed
- none

### Checkpoints
- iOS build (device): rough (the missing Rust target; see Rough), then smooth (1.5 min)
- driving the app on a phone (`agent ios --device`): smooth
- `verify ios`: smooth (clean)
