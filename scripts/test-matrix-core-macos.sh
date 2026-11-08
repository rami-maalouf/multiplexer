#!/usr/bin/env bash
# runs the auth-free matrix-core tests natively on apple silicon, without a simulator.
# hold the shared lock: scripts/mx-lock.sh matrixcore mac-core -- scripts/test-matrix-core-macos.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
vendor="$root/vendor/matrix-sdk/26.10.27"
framework="$vendor/combined/MatrixSDKFFI.xcframework"
sdk="$root/matrix-core/.build/macos-sdk"

if [ ! -f "$framework/macos-arm64/libmatrix_sdk_ffi.a" ] || [ ! -d "$vendor/src/Sources/MatrixRustSDK" ]; then
  echo "missing local macos sdk: run scripts/setup-matrix-sdk.sh and scripts/build-matrix-sdk-macos.sh, then setup again" >&2
  exit 1
fi

mkdir -p "$sdk/Sources"
cp -p "$root/matrix-core/MacTestSupport/Package.swift" "$sdk/Package.swift"
if [ ! -d "$sdk/MatrixSDKFFI.xcframework" ] || \
   [ "$framework/macos-arm64/libmatrix_sdk_ffi.a" -nt "$sdk/MatrixSDKFFI.xcframework/macos-arm64/libmatrix_sdk_ffi.a" ]; then
  rm -rf "$sdk/MatrixSDKFFI.xcframework"
  cp -cpR "$framework" "$sdk/MatrixSDKFFI.xcframework"
fi
mkdir -p "$sdk/Sources/MatrixRustSDK"
cp -cp "$vendor"/src/Sources/MatrixRustSDK/*.swift "$sdk/Sources/MatrixRustSDK/"

MATRIX_CORE_MACOS=1 swift test --package-path "$root/matrix-core" \
  --scratch-path "$root/matrix-core/.build/macos" --force-resolved-versions --jobs 2 "$@"
