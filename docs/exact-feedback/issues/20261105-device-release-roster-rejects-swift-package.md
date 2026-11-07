# A device release cannot qualify a target-only Swift package roster

**Status:** Open
**Systems:** iOS device build, Swift package modules, roster qualification
**Severity:** P2
**Author:** Rami Maalouf, via a local agent report
**Date:** 2026-11-05
**Finding:** 126

**Local status note:** Open, local only

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
