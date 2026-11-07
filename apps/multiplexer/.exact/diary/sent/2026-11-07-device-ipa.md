surfaces: ios
agent: Claude Opus 5.5
task: build a chat app's iOS device .ipa to share through a third-party install-link service

### Rough
- `bun exact.mjs ios --device --archive <out.ipa> --unsigned` built for 3.5 minutes, then failed at the end: "host/apple: cannot qualify <app id>'s iOS native-module roster. Mac Catalyst / iOS Simulator / macOS: <package> (a Swift package, compiled for this build's target) has no ... slice ... A production build does not take the manifest's roster". The app has its own module with a view tag and also Swift-source packages (`@exact/camera`, `in-app-browser`, ...). In `host/apple/build.mjs` the roster probe routes skip every route when packages exist and the build is not a simulator build, so a device archive of such an app can never pass. The commit that added the skip says no app in the repo had module tags and packages together. The message's advice ("give each xcframework a slice") does not apply: these are source packages, not xcframeworks. About 15 minutes to find the cause. What would have helped: the probe compiling the packages for its own route's target, or the device build reading the roster from its own (device) artifact; and a check before the 3-minute compile, so the failure comes first.

- Building against my own framework worktree again needed the framework's path rewritten in five app files (the four Cargo/manifest files and `package.json`, whose packages pointed at a third checkout). Evidence for the known finding on building against another framework checkout.

- With the roster fixed, the archive stopped at "registerForRemoteNotifications refused (LLP 1126.001 WP9)": every archive refuses the call, also with no Live Activity. For this one archive the call was replaced by a "no token" answer in an uncommitted copy. About 10 minutes. Known finding (remote push).
- The archive also asked for an app icon ("a distribution bundle requires an AppIcon") only after the 3-minute compile; a check before the compile would have saved a build.

### Lean in
- The fix stayed small: package compiles take a "place" (a directory and a target). The build keeps its own place; on a device build each roster route compiles the packages for its own target in its own directory, and the existing arm cache keys them. A simulator build keeps the old skip, so a failing probe does not compile again each build.

### Checkpoints
- First try: no .ipa produced, nothing uploaded.
- With the fix on the framework's latest main: the roster was read on the iOS Simulator route, and the archive was made (38.8 MB) and shared through the install-link service.
