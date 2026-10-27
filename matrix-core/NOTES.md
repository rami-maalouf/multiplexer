# MatrixCore: how matrix-rust-sdk links into the app

## The Exact app (iOS)

`scripts/setup-matrix-sdk.sh` does all of it. Run it after a fresh clone and after
every edit in `matrix-core/`.

1. It downloads `MatrixSDKFFI.xcframework.zip` for version `26.10.27` from
   `element-hq/matrix-rust-components-swift` and checks its SHA-256 against the
   checksum in that release's `Package.swift`.
2. It clones the release's generated Swift bindings (`Sources/MatrixRustSDK`, 9 files).
3. It copies these into `apps/multiplexer/modules/apple/`:
   - `MatrixSDKFFI.xcframework`: a static library with `ios-arm64` and `ios-arm64-simulator` slices.
   - `sdk-*.swift`: the bindings.
   - `core-*.swift`: `matrix-core/Sources/MatrixCore/*.swift`.

Exact compiles every top-level `.swift` file in `modules/apple/` into one module and
links each xcframework slice with `-I`, `-L` and `-l` (`host/apple/build.mjs`,
`frameworkSlice`). The bindings import `MatrixSDKFFI` behind `#if canImport`, and the
compiler finds its module map in the slice's `Headers/MatrixSDKFFI/`.

- **Copies, not symlinks.** Exact refuses symlinks in the app folder
  (`source links are not captured`). The script makes APFS clones (`cp -c`), which use
  no extra disk space.
- **Not in git.** `.gitignore` lists the copies and `vendor/`.
- **Deployment target.** `app.json` sets iOS 17.0. The SDK needs iOS 16.
- **Linker flags.** None were needed.
- **The boundary.** All files compile into one module, so the rule "only MatrixCore
  calls the SDK" is a convention here. `Matrix.swift` (the native module) calls only
  `MatrixCore`.

## Proof (2026-10-27)

- The iPhone 17 Pro Simulator shows `14a0ada4fc`, which `sdkGitSha()` returned. The
  release's commit message names matrix-rust-sdk `14a0ada4fcb3…`.
- `bun exact.mjs test ios`: 1 passed, 0 failed.
- Build time: 49 s in total, of which 41.7 s compiles the module Swift.
- Size: the Simulator debug app is 109 MB; `libexact_modules.dylib` is 69 MB of it.

## Known costs and open questions

- **Rebuild time.** An edit to any module Swift file recompiles the 2 MB of bindings
  (about 40 s). If this slows T1.3 and later, build the bindings and MatrixCore into one
  prebuilt xcframework, so the app module compiles only `Matrix.swift`.
- **Device build.** Not tried yet. It needs signing (Q4). The `ios-arm64` slice exists.
- **Mac.** The release has no macOS slice. The Mac app (M5) needs our own build of the
  bindings.
- **Swift package.** For T1.3's tests and the Expo fallback, MatrixCore also builds as a
  Swift package that depends on `MatrixRustSDK`. Its files import it behind
  `#if canImport(MatrixRustSDK)`, so the same files compile in both places.
