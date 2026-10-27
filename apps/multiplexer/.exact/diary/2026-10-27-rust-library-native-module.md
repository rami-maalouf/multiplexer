surfaces: ios
agent: Claude Code, Claude Opus 5.5
task: link a large third-party Rust library (a static xcframework plus generated Swift bindings) into a native module and call it

### Rough
- Linked the vendor's Swift bindings and xcframework into `modules/apple/` with symlinks (to keep a 168 MB binary out of the app folder and out of git). `contract build` failed with `source links are not captured: …/modules/apple/<a binding file>.swift` (from `js/bake`'s source capture, which refuses every symlink in the app except `.md`/`.txt`). ~10 min. Switched to APFS clones (`cp -c`) from a setup script. What would have helped: the message naming the native module folder's rule, or the capture skipping `modules/apple` (Swift and xcframeworks are not TypeScript sources), or `app-json.md` saying "real files, no links". The workaround stays in the app's AGENTS.md: "after an edit to the shared Swift, run the setup script again, or the app builds the old copy". Every later edit to that Swift pays this step.

- The same Swift (a wrapper around the library) also had to build as a Swift package, for its own XCTests. `modules/apple` compiles every file into one module with the bindings, so the files import the library behind `#if canImport(…)` and the setup script copies them in. ~10 min. What would have helped: a documented way for a module to depend on a local Swift package, or on a folder of Swift outside `modules/apple`.

- Each module build compiles all of `modules/apple` as one module, so the 2 MB of vendor bindings compile again on every edit to the app's own small module file: 31 to 42 s (`arms` in the build line, measured twice) for a one-line change, and every Swift edit in the next two tasks paid it. What would have helped: the vendor's Swift compiled once and cached by its sources, apart from the app's own file. Found later, not tried: Exact packages (`exact.json`, `packages/fixtures/swatch`) compile as their own Swift module, but `host/apple/build.mjs` seems to compile each package again whenever the module arm rebuilds (read in the code, not measured). The native-module recipe does not mention packages, so I did not find them while building.

- `agent ios "prefer dark"` failed with a long list of accepted keys; the step is `prefer prefers-color-scheme dark`. ~2 min. A suggestion of the nearest key ("did you mean prefers-color-scheme dark?") would have helped.

### Lean in
- `modules/apple/*.xcframework` already links a static library slice with `-I`, `-L` and `-l`, read from the xcframework's own Info.plist. A vendor's prebuilt xcframework could drop in without a Swift package.

- The first module build with 2 MB of generated Swift and an 84 MB static library took 49 s and needed no linker flags. The roster probe found the simulator slice on its own.
- `agent ios "state"` showed the native answer in `resources`, so the proof needed no screenshot reading.

### Needed
- third-party native library: provided (a vendor xcframework and its Swift in `modules/apple/`), rough (no symlinks, no package dependency, a full recompile per edit; see Rough)

### Checkpoints
- install / first build: smooth (`setup --check` ready; first iOS build about 2 min)
- `exact new`: smooth (`--name`, `--bundle-id`, then `update --without linux`).
- editing app.contract / app.ts: smooth
- iOS build: smooth the first time (49 s with the library), rough after (31 to 42 s for each one-line Swift edit; see Rough)
- driving the app (`exact.mjs agent`, `exact.mjs test`): rough (`prefer` syntax; see Rough), then smooth
