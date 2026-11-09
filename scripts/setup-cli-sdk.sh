#!/usr/bin/env bash
# builds matrix-rust-sdk for macOS (apple silicon) from the same commit as the app's sdk
# release, and puts the framework and its swift bindings where the cli package finds them
# (cli/.sdk, gitignored). element publishes ios slices only, so the mac build is ours.
#
# the first build takes several minutes; later runs reuse it. needs rustup (~/.cargo/bin)
# with the `stable` toolchain, which the sdk's build tool calls by name.
set -euo pipefail

# the commit element's release 26.10.27 was built from (its "Bump to version" commit message).
# keep it equal to scripts/setup-matrix-sdk.sh's version, so the app and the cli run one sdk.
release="26.10.27"
# equal to cli/Package.swift's platform: c code in the sdk (sqlite) otherwise targets this mac's os.
macos="14.0"
commit="14a0ada4fcb3a93f47248b6abefbd04ceaf71e5d"
repo="https://github.com/matrix-org/matrix-rust-sdk.git"

root="$(cd "$(dirname "$0")/.." && pwd)"
src="$root/vendor/matrix-rust-sdk"
generated="$src/bindings/apple/generated"
stamp="$generated/.built-commit"
out="$root/cli/.sdk"

export PATH="$HOME/.cargo/bin:$PATH"
command -v rustup >/dev/null || { echo "setup-cli-sdk: rustup not found (install it from rustup.rs)" >&2; exit 1; }

# the app's release names its sdk commit: refuse to build another one.
app_release="$root/vendor/matrix-sdk/$release/src"
if [ -d "$app_release/.git" ] && ! git -C "$app_release" log -n 1 --format=%s | grep -q "$commit"; then
  echo "setup-cli-sdk: release $release was not built from $commit" >&2
  exit 1
fi

if [ "$(git -C "$src" rev-parse HEAD 2>/dev/null || true)" != "$commit" ]; then
  rm -rf "$src"
  mkdir -p "$src"
  git -C "$src" init -q
  git -C "$src" remote add origin "$repo"
  git -C "$src" fetch -q --depth 1 origin "$commit"
  git -C "$src" checkout -q FETCH_HEAD
fi

if [ "$(cat "$stamp" 2>/dev/null || true)" != "$commit macos $macos" ]; then
  rustup toolchain list | grep -q '^stable' || rustup toolchain install stable --profile minimal
  # cargo keeps c objects (blake3, sqlite) built for an older target: start the mac build clean.
  rm -rf "$src/target/aarch64-apple-darwin"
  # the sdk's release build unsets it too: a set SDKROOT breaks the build for other targets.
  (cd "$src" && unset SDKROOT && cargo xtask swift build-framework --release --target aarch64-apple-darwin \
    --macos-deployment-target "$macos")
  echo "$commit macos $macos" > "$stamp"
fi

rm -rf "$out"
mkdir -p "$out/MatrixRustSDK"
cp -cR "$generated/MatrixSDKFFI.xcframework" "$out/MatrixSDKFFI.xcframework"
cp -c "$generated"/swift/*.swift "$out/MatrixRustSDK/"
echo "matrix-rust-sdk $commit (release $release) for macOS copied into cli/.sdk"
