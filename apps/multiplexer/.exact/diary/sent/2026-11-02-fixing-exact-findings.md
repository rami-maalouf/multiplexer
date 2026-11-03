surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: fix the framework's open findings from this app in pull requests to the framework, each reproduced first on the framework's newest commit

### Rough
- `host/apple/build.mjs --test` (the Swift host tests) refuses to start without Xcode's Metal toolchain: "this build compiles the SVG filter kernels with Xcode's Metal toolchain, which is not installed. Install it with `xcodebuild -downloadComponent MetalToolchain`". An app's build on the same machine goes on without it ("no SVG filter kernels (no Metal toolchain)"). Installing an Xcode component changes every other session's builds on the machine, so I ran the tests with a local edit that made the kernels optional (`svgFilterLibrary(..., false)`) and undid it after. Cost about 10 minutes. What would have helped: the tests skipping the SVG filter tests (or marking them as missing a prerequisite) when the toolchain is missing, as a build does.
- The host tests have no way to run one test class: `--test` builds and runs all 318 classes (more than 10 minutes on this machine, so a first run in the foreground was killed at the tool's limit). To rerun one class I found the bundle under `target/clients/<hash>/…/tests/out/Products/Debug/ExactKitTests.xctest` and ran `xcrun xctest -XCTest ExactKitTests.RasterImageTests <bundle>`. Cost about 15 minutes. What would have helped: `--test --only <Class>` (or a line in docs/testing.md giving the `xctest` command and the bundle path).
- `bun scripts/caps.mjs` said "host/apple/build.mjs is 1501 lines, over the cap of 1500" when `wc -l` said 1500: caps counts the empty string after the last newline as a line. I needed one more line cut than I had planned. Cost about 3 minutes. What would have helped: the cap counting lines as `wc -l` does, or its message saying how it counts.

### Lean in
- `agent ios` drives hold a lock per simulator and app (`exclusiveIOS`), so a second drive waits and a third session's drive is refused with a clear message; reusing that lock for `ios --run` was a small change.
- `pick <input-id> <path>` in a drive picks a real file into the app's `app:/tmp/picked/`, and `logs` showed the image's failure line ("image deferred: no image size in its first 262144 bytes").
- `--reset-storage` made a second drive start from the same screen as the first.
- A sample app with a file tray (`excord`) reproduced an app's bug in the framework's own tree, without the app.

### Needed
- running one host test class: missing (`xcrun xctest -XCTest <Class> <bundle>` instead)
- host tests without the Metal toolchain: missing (a local edit instead)

### Checkpoints
- framework host tests (`build.mjs --test`): rough (see Rough)
- framework script tests (`bun test` with the pinned Bun): smooth
- driving a sample app on iOS (`scripts/agent.mjs ios --app`): smooth after `build.mjs --ios <app>-apple`, which the refusal named
