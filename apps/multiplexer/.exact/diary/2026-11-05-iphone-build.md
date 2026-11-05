surfaces: ios
agent: codex gpt-6-astra
task: build and install the current native app on a paired phone

### Rough

- a physical-phone release compiled rust and swift but failed roster qualification after about 282 seconds. a declared browser swift package had only the selected device target; the available qualification routes required mac catalyst, simulator or macos. the error asked for xcframework slices despite identifying a swift package. preserved the release failure and built the supported development configuration, which passed in 183 seconds. a preflight or package-specific qualification route would avoid this late failure. local finding 126.

### Lean in

- automatic development profile selection produced a valid signed app for the paired phone. installation completed in about eight seconds without opening the app.

### Needed

- physical-device signing and installation: provided.
- production native-module qualification for a target-only swift package: blocked.

### Checkpoints

- release build: failed before installation; source and prior bundles preserved.
- development build: passed; signature, arm64 and provisioning coverage checked.
- phone installation: passed; subsequent inventory matches the installation url and version.
- account and ui runtime: not exercised; the app was left closed.
- feedback status: ask; standing local-only instruction retained, nothing sent.
