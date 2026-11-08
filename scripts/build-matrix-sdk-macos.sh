#!/usr/bin/env bash
# builds the macos (apple silicon) slice of the pinned matrix-rust-sdk, which the
# released swift package does not ship (it is ios only). setup-matrix-sdk.sh then adds
# it to the xcframework beside the released ios slices. run once per sdk version, and
# again only when the pin changes. it takes about 5 minutes on an m-series mac (a release build with lto).
set -euo pipefail

version="26.10.27"
# the sdk commit the released components were built from (the components repo's
# "bump to version 26.10.27" commit names it).
commit="14a0ada4fcb3a93f47248b6abefbd04ceaf71e5d"
macos_minimum="14.0" # apps/multiplexer/app.json, host.macos.minimumOS

root="$(cd "$(dirname "$0")/.." && pwd)"
vendor="$root/vendor/matrix-sdk/$version"
sdk="$root/vendor/matrix-rust-sdk"
out="$vendor/macos-arm64"

if [ ! -d "$vendor/src" ]; then
  echo "run scripts/setup-matrix-sdk.sh first: it fetches the released swift sources" >&2
  exit 1
fi
command -v cargo >/dev/null || export PATH="$HOME/.cargo/bin:$PATH"
rustup target add aarch64-apple-darwin >/dev/null

if [ ! -d "$sdk/.git" ]; then
  git clone -q --filter=blob:none https://github.com/matrix-org/matrix-rust-sdk.git "$sdk"
fi
git -C "$sdk" fetch -q origin "$commit" 2>/dev/null || true
git -C "$sdk" checkout -q --detach "$commit"

(cd "$sdk" && cargo xtask swift build-framework --release --target aarch64-apple-darwin --macos-deployment-target "$macos_minimum")

generated="$sdk/bindings/apple/generated"
# the swift bindings must be the released ones byte for byte: they carry the checksums
# that the library checks when it loads, and the app compiles the released copies.
if ! diff -r -q "$generated/swift" "$vendor/src/Sources/MatrixRustSDK" >/dev/null; then
  echo "the macos build's swift bindings differ from the released $version sources:" >&2
  diff -r -q "$generated/swift" "$vendor/src/Sources/MatrixRustSDK" >&2 || true
  exit 1
fi

slice="$(cd "$generated/MatrixSDKFFI.xcframework" && ls -d macos-* | head -n 1)"
if ! diff -r -q "$generated/MatrixSDKFFI.xcframework/$slice/Headers" "$vendor/unpacked/MatrixSDKFFI.xcframework/ios-arm64/Headers" >/dev/null; then
  echo "the macos build's ffi headers differ from the released ios ones" >&2
  exit 1
fi
rm -rf "$out"
mkdir -p "$out"
cp -R "$generated/MatrixSDKFFI.xcframework/$slice/." "$out/"
echo "matrix-rust-sdk $version macos slice in $out ($(du -sh "$out/libmatrix_sdk_ffi.a" | cut -f1))"
