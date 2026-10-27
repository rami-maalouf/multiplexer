#!/usr/bin/env bash
# downloads the pinned matrix-rust-sdk swift bindings, checks the binary against
# the checksum in the release's Package.swift, and copies the sdk and matrix-core
# into the exact app's native module folder.
set -euo pipefail

version="26.10.27"
checksum="a44ed51afdf6a65d07801eddfb8eec8ff084776862ebd4de0f4c0ff887b8fc7e"
repo="https://github.com/element-hq/matrix-rust-components-swift"

root="$(cd "$(dirname "$0")/.." && pwd)"
vendor="$root/vendor/matrix-sdk/$version"
modules="$root/apps/multiplexer/modules/apple"

if [ ! -d "$vendor/unpacked/MatrixSDKFFI.xcframework" ]; then
  mkdir -p "$vendor"
  curl -fsSL -o "$vendor/MatrixSDKFFI.xcframework.zip" "$repo/releases/download/$version/MatrixSDKFFI.xcframework.zip"
  (cd "$vendor" && echo "$checksum  MatrixSDKFFI.xcframework.zip" | shasum -a 256 -c -)
  unzip -q -o "$vendor/MatrixSDKFFI.xcframework.zip" -d "$vendor/unpacked"
fi
if [ ! -d "$vendor/src" ]; then
  git clone -q --depth 1 --branch "$version" "$repo.git" "$vendor/src"
fi

# exact compiles every top-level .swift file in modules/apple into one module
# and links every .xcframework there. it refuses symlinks in the app, so these
# are copies: apfs clones (cp -c), which cost no disk space.
mkdir -p "$modules"
rm -rf "$modules"/sdk-*.swift "$modules"/core-*.swift "$modules/MatrixSDKFFI.xcframework"
cp -cR "$vendor/unpacked/MatrixSDKFFI.xcframework" "$modules/MatrixSDKFFI.xcframework"
for f in "$vendor"/src/Sources/MatrixRustSDK/*.swift; do
  cp -c "$f" "$modules/sdk-$(basename "$f")"
done
# rerun this script after an edit in matrix-core.
for f in "$root"/matrix-core/Sources/MatrixCore/*.swift; do
  cp -c "$f" "$modules/core-$(basename "$f")"
done
echo "matrix-rust-sdk $version and matrix-core copied into apps/multiplexer/modules/apple"
