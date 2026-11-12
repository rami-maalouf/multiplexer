#!/usr/bin/env bash
# adds the notification service extension to an app exact built, and gives the app what push
# needs: aps-environment and the app group. exact cannot build an app's own extension or declare
# those entitlements (docs/exact-feedback, "an app cannot add its own app extension"), so this
# runs after exact's build, then signs for export or installs the result.
#
#   scripts/add-notification-extension.sh --sim <udid> <Mux.app>
#       a simulator build: ad-hoc signed. the simulator reads entitlements from the binary's
#       __TEXT,__entitlements section, so the app's is rewritten in place (same size).
#   scripts/add-notification-extension.sh --device <phone udid> <Mux.app>
#       a phone build, signed with the identity exact used and the two development profiles of
#       APP_PROFILE and EXTENSION_PROFILE: .mobileprovision paths in the environment.
#   scripts/add-notification-extension.sh --store <archive dSYMs directory> <Mux.app>
#       a store archive: ad-hoc signed with production push, no profiles and no install.
#       xcode export supplies distribution profiles and signatures for both products.
#
# the extension compiles matrix-core and the sdk's bindings (the copies setup-matrix-sdk.sh makes)
# with apps/multiplexer/extensions/notifications/*.swift; the build is cached by its inputs.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="$root/apps/multiplexer"
modules="$app_dir/modules/apple"
config="$(bun "$root/scripts/ios-config.ts" --shell)"
{ read -r team; read -r app_id; read -r extension_id; read -r group; read -r session_service; read -r push_gateway; } <<< "$config"
name="MultiplexerNotifications"


mode="${1:-}"; target="${2:-}"; app="${3:-}"
case "$mode" in --sim|--device|--store) ;; *) echo "usage: $0 --sim <udid> <app> | --device <phone udid> <app> | --store <dSYMs directory> <app>" >&2; exit 2 ;; esac
[ -n "$target" ] && [ -d "$app" ] || { echo "usage: $0 $mode <udid> <path to Mux.app>" >&2; exit 2; }
actual_id="$(plutil -extract CFBundleIdentifier raw -o - "$app/Info.plist")"
[ "$actual_id" = "$app_id" ] || { echo "built app identity differs from configured bundleId" >&2; exit 1; }
if [ "$mode" = "--device" ]; then
  bun "$root/scripts/ios-config.ts" --preflight "$target" "$app"
fi
ls "$modules"/core-*.swift >/dev/null 2>&1 || { echo "no matrix-core copies in $modules: run scripts/setup-matrix-sdk.sh" >&2; exit 1; }

if [ "$mode" = "--sim" ]; then
  sdk_name=iphonesimulator; triple=arm64-apple-ios17.0-simulator; slice=ios-arm64-simulator
  prefix=SIMULATORX; platform=iPhoneSimulator
else
  sdk_name=iphoneos; triple=arm64-apple-ios17.0; slice=ios-arm64
  prefix="$team"; platform=iPhoneOS
  if [ "$mode" = "--device" ]; then
    : "${APP_PROFILE:?set APP_PROFILE to the app's development profile (P3.0)}"
    : "${EXTENSION_PROFILE:?set EXTENSION_PROFILE to the extension's development profile (P3.0)}"
  fi
fi
keychain_group="$prefix.$app_id"
sdk="$(xcrun --sdk "$sdk_name" --show-sdk-path)"
ffi="$modules/MatrixSDKFFI.xcframework/$slice"

work="$app_dir/target/notifications/$sdk_name"
if [ "$mode" = "--store" ]; then work="$work-store"; fi
mkdir -p "$work"

# the extension's entitlements: its own id, the app's keychain group (where the session is) and
# the app group (where the store is).
ext_ent="$work/extension.entitlements"
cat > "$ext_ent" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>application-identifier</key><string>$prefix.$extension_id</string>
  $( [ "$mode" != "--sim" ] && echo "<key>com.apple.developer.team-identifier</key><string>$team</string>" )
  <key>keychain-access-groups</key><array><string>$keychain_group</string></array>
  <key>com.apple.security.application-groups</key><array><string>$group</string></array>
  <key>get-task-allow</key><$( [ "$mode" = "--store" ] && echo false || echo true )/>
</dict></plist>
EOF

# compile, unless these very inputs were compiled before (the bindings alone take about a minute).
sources=("$modules"/sdk-*.swift "$modules"/core-*.swift "$app_dir"/extensions/notifications/*.swift)
key="$( { cat "${sources[@]}" "$ext_ent" "$root/scripts/add-notification-extension.sh"; echo "$triple"; shasum -a 256 "$ffi/libmatrix_sdk_ffi.a"; } | shasum -a 256 | cut -c1-16)"
binary="$work/$name-$key"
if [ ! -x "$binary" ]; then
  echo "compiling the notification extension (about a minute)"
  # under `set -u`, an empty "${array[@]}" is unbound; only pass the simulator
  # entitlement section when this is a simulator build.
  sim_ent=()
  debug=()
  if [ "$mode" = "--store" ]; then debug=(-g); fi
  if [ "$mode" = "--sim" ]; then
    sim_ent=(-Xlinker -sectcreate -Xlinker __TEXT -Xlinker __entitlements -Xlinker "$ext_ent")
  fi
  xcrun --sdk "$sdk_name" swiftc -parse-as-library -O -wmo -swift-version 5 \
    ${debug[@]+"${debug[@]}"} -application-extension -Xlinker -e -Xlinker _NSExtensionMain \
    -module-name "$name" -target "$triple" -sdk "$sdk" -module-cache-path "$work/module-cache" \
    -I "$ffi/Headers" -L "$ffi" -lmatrix_sdk_ffi ${sim_ent[@]+"${sim_ent[@]}"} \
    "${sources[@]}" -o "$binary.tmp"
  if [ "$mode" = "--store" ]; then mv "$binary.tmp.dSYM" "$binary.dSYM"; fi
  mv "$binary.tmp" "$binary"
  find "$work" -maxdepth 1 -name "$name-*" ! -name "$name-$key" ! -name "$name-$key.dSYM" -exec rm -rf {} +
fi

# the extension's bundle, beside the app's own versions.
info() { plutil -extract "$1" raw -o - "$app/Info.plist"; }
# preserve any other activity types supplied by the app.
if ! /usr/libexec/PlistBuddy -c 'Print :NSUserActivityTypes' "$app/Info.plist" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c 'Add :NSUserActivityTypes array' "$app/Info.plist"
fi
if ! /usr/libexec/PlistBuddy -c 'Print :NSUserActivityTypes' "$app/Info.plist" | grep -q INSendMessageIntent; then
  /usr/libexec/PlistBuddy -c 'Add :NSUserActivityTypes:0 string INSendMessageIntent' "$app/Info.plist"
fi
# runtime configuration belongs to the packaged bundle, never compiled credentials.
for metadata in MultiplexerAppGroup MultiplexerKeychainGroup MultiplexerSessionService MultiplexerPushGateway; do
  case "$metadata" in
    MultiplexerAppGroup) value="$group" ;;
    MultiplexerKeychainGroup) value="$keychain_group" ;;
    MultiplexerSessionService) value="$session_service" ;;
    MultiplexerPushGateway) value="$push_gateway" ;;
  esac
  plutil -replace "$metadata" -string "$value" "$app/Info.plist"
done
appex="$app/PlugIns/$name.appex"
rm -rf "$appex"
mkdir -p "$appex"
cp "$binary" "$appex/$name"
cat > "$appex/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$extension_id</string>
  <key>CFBundleExecutable</key><string>$name</string>
  <key>CFBundleName</key><string>$name</string>
  <key>CFBundleDisplayName</key><string>$(info CFBundleDisplayName 2>/dev/null || info CFBundleName)</string>
  <key>CFBundlePackageType</key><string>XPC!</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleShortVersionString</key><string>$(info CFBundleShortVersionString)</string>
  <key>CFBundleVersion</key><string>$(info CFBundleVersion)</string>
  <key>MinimumOSVersion</key><string>$(info MinimumOSVersion)</string>
  <key>CFBundleSupportedPlatforms</key><array><string>$platform</string></array>
  <key>DTPlatformName</key><string>$( [ "$mode" = "--sim" ] && echo iphonesimulator || echo iphoneos )</string>
  <key>DTPlatformVersion</key><string>$(info DTPlatformVersion 2>/dev/null || echo 17.0)</string>
  <key>UIRequiredDeviceCapabilities</key><array><string>arm64</string></array>
  <key>MultiplexerAppGroup</key><string>$group</string>
  <key>MultiplexerKeychainGroup</key><string>$keychain_group</string>
  <key>MultiplexerSessionService</key><string>$session_service</string>
  <key>NSUserActivityTypes</key><array><string>INSendMessageIntent</string></array>
  <key>NSExtension</key><dict>
    <key>NSExtensionPointIdentifier</key><string>com.apple.usernotifications.service</string>
    <key>NSExtensionPrincipalClass</key><string>NotificationService</string>
  </dict>
</dict></plist>
EOF

if [ "$mode" = "--sim" ]; then
  # the app's simulated entitlements, rewritten in place: exact's section has no room to grow, so
  # this is a compact plist padded with spaces to the section's size. it keeps exact's
  # application-identifier and first keychain group, and adds push and the app group.
  # omit the simulator-only debugger grant to fit communication notifications; phone signing
  # keeps its original debug entitlement. native drives use the compiled development host.
  binary_path="$app/$(info CFBundleExecutable)"
  read -r offset hex_size < <(xcrun otool -l "$binary_path" | awk '/sectname __entitlements/ {found=1} found && /^ *size/ {s=$2} found && /^ *offset/ {print $2, s; exit}')
  [ -n "${offset:-}" ] || { echo "no __entitlements section in $binary_path" >&2; exit 1; }
  size=$((16#${hex_size#0x}))
  current="$(dd if="$binary_path" bs=1 skip="$offset" count="$size" 2>/dev/null)"
  case "$current" in *"<string>$prefix.$app_id</string>"*) ;; *) echo "the app's entitlements are not exact's simulator ones: $current" >&2; exit 1 ;; esac
  xml="<plist><dict><key>application-identifier</key><string>$prefix.$app_id</string><key>keychain-access-groups</key><array><string>$keychain_group</string></array><key>aps-environment</key><string>development</string><key>com.apple.developer.usernotifications.communication</key><true/><key>com.apple.security.application-groups</key><array><string>$group</string></array></dict></plist>"
  [ "${#xml}" -le "$size" ] || { echo "the entitlements ($((${#xml})) bytes) do not fit exact's section ($size bytes)" >&2; exit 1; }
  printf "%-${size}s" "$xml" | dd of="$binary_path" bs=1 seek="$offset" conv=notrunc 2>/dev/null
  codesign -f -s - "$appex"
  codesign -f -s - "$app"
  xcrun simctl install "$target" "$app"
elif [ "$mode" = "--store" ]; then
  mkdir -p "$target"
  cp -R "$binary.dSYM" "$target/$name.appex.dSYM"
  # export reads these requested entitlements and selects distribution profiles for both ids.
  app_ent="$work/app.entitlements"
  cat > "$app_ent" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>application-identifier</key><string>$team.$app_id</string>
  <key>com.apple.developer.team-identifier</key><string>$team</string>
  <key>get-task-allow</key><false/>
  <key>aps-environment</key><string>production</string>
  <key>com.apple.developer.usernotifications.communication</key><true/>
  <key>keychain-access-groups</key><array><string>$keychain_group</string></array>
  <key>com.apple.security.application-groups</key><array><string>$group</string></array>
</dict></plist>
EOF
  codesign -f -s - --entitlements "$ext_ent" "$appex"
  codesign -f -s - --entitlements "$app_ent" "$app"
else
  # the phone: the profiles of P3.0, and the identity exact signed the app with.
  # use the actual signer's fingerprint: multiple development certificates can share a name.
  codesign -d --extract-certificates="$work/signing-cert-" "$app" 2>/dev/null
  identity="$(shasum -a 1 "$work/signing-cert-0" | awk '{print $1}')"
  [ -n "$identity" ] || { echo "the app is not signed with a development identity" >&2; exit 1; }
  cp "$EXTENSION_PROFILE" "$appex/embedded.mobileprovision"
  cp "$APP_PROFILE" "$app/embedded.mobileprovision"
  app_ent="$work/app.entitlements"
  codesign -d --entitlements :- "$app" > "$app_ent" 2>/dev/null
  # plutil inserts missing keys; literal dots in an entitlement key must be escaped.
  plutil -replace aps-environment -string development "$app_ent"
  plutil -replace 'com\.apple\.developer\.usernotifications\.communication' -bool true "$app_ent"
  plutil -replace 'com\.apple\.security\.application-groups' -json "[\"$group\"]" "$app_ent"
  plutil -replace keychain-access-groups -json "[\"$keychain_group\"]" "$app_ent"
  codesign -f -s "$identity" --entitlements "$ext_ent" "$appex"
  codesign -f -s "$identity" --entitlements "$app_ent" "$app"
  xcrun devicectl device install app --device "$target" "$app"
fi
if [ "$mode" = "--store" ]; then
  echo "the notification extension is in $app, ready for distribution signing at export"
else
  echo "the notification extension is in $app and installed on $target"
fi
