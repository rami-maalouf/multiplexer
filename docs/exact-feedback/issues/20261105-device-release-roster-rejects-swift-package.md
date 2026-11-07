# A device release cannot qualify a target-only Swift package roster

**Status:** Open, local only
**Systems:** iOS device build, Swift package modules, roster qualification
**Severity:** P2
**Date:** 2026-11-05
**Finding:** 126

## Observed behavior

An existing app with a declared `in-app-browser` Swift package builds its Rust and
Swift components for a physical iPhone, then `ios --device --release --no-install`
fails during native-module roster qualification. The package is compiled for the
selected device target; all three host-side qualification routes reject it:

```text
Mac Catalyst: in-app-browser (a Swift package, compiled for this build's target) has no Mac Catalyst slice
iOS Simulator: in-app-browser (a Swift package, compiled for this build's target) has no iOS Simulator slice
macOS: in-app-browser (a Swift package, compiled for this build's target) has no macOS slice
```

The error asks for additional xcframework slices even though this dependency is a
Swift package. The release attempt stopped after 281.714 seconds, before signing a
new deliverable or installing it. Exact source was unchanged at `d0d66b107e`.

## Result and limits

The supported signed development build passed in 183.098 seconds. It retains the
development-mode manifest roster fallback, so this is not a successful production
qualification. Its signature, arm64 architecture and phone provisioning coverage
were verified, and installation succeeded. No framework workaround or release-gate
bypass was introduced. The previous artifacts and failed release log were preserved.

## Needed

Qualify declared Swift package modules through a supported host-side build route,
or reject this unsupported combination before the expensive device compilation.
The diagnostic should name the package-specific remedy instead of requesting
xcframework slices. This report does not establish which implementation is correct.

Feedback remains local; nothing sent publicly.

## Evidence (2026-11-07): the cause, and a local fix

Seen again with `ios --device --archive <out.ipa> --unsigned` (the archive for a re-signing
install-link service), at the integration checkout `e2b58b6992`, after about 3.5 minutes of compiling.

Cause: `host/apple/build.mjs` compiles the Swift packages once, for the build's own target, and
marks every roster route that does not share that target as lacking. A simulator build's simulator
route shares it; a device build has no such route, so with packages and a module tag a device
archive can never pass.

Local fix, on exact2's `main` of 2026-11-07 (`f3fa06164e`): commit `71382b8307` on the local
branch `local/mx-device-ipa`. Package compiles take a place (a directory and a target). The build
keeps its own place; on a device build each roster route compiles the packages for its own target,
in its own directory, keyed by the existing arm cache. A simulator build keeps the old skip, so a
probe that cannot link does not compile again on each build. Result: "the module roster was read on
iOS Simulator", and the archive was made. `host/apple/arms.test.mjs` passes. Not yet a pull request.
