#!/usr/bin/env bash
# builds mux for the app store and uploads it to testflight.
#   ./scripts/testflight.sh <build number>            # build, sign, upload
#   ./scripts/testflight.sh <build number> --export   # build and sign only (no upload)
#   ./scripts/testflight.sh <build number> --archive-only # package only (no export/upload)
# the build number must rise with each upload (app store connect refuses a repeat).
#
# exact builds an unsigned archive; xcode then signs it with the team's cloud-managed
# distribution certificate and its app store profile (made on the fly by
# -allowProvisioningUpdates with the apple account signed in to xcode) and uploads it.
# no distribution certificate or profile is needed on this mac. the app record must exist
# in app store connect first (bundle id com.ramimaalouf.multiplexer).
# EXACT2 names the exact checkout, as for exact.mjs.
set -euo pipefail

if [ $# -lt 1 ] || ! [[ "$1" =~ ^[0-9]+$ ]]; then
  echo "usage: $0 <build number> [--export|--archive-only]" >&2
  exit 1
fi
build="$1"
destination="upload"
archive_only=false
case "${2:-}" in
  "") ;;
  --export) destination="export" ;;
  --archive-only) destination="export"; archive_only=true ;;
  *) echo "unknown option: $2" >&2; exit 2 ;;
esac
[ $# -le 2 ] || { echo "too many arguments" >&2; exit 2; }

team="3V2UU7RRK9"
bundle="com.ramimaalouf.multiplexer"
version="${EXACT_VERSION:-0.1.0}"
here="$(cd "$(dirname "$0")" && pwd)"
app_dir="$here/../apps/multiplexer"
work="$(mktemp -d /tmp/mx-testflight-XXXXXX)"
echo "work folder: $work"

# 1. exact's archive, unsigned (ad hoc), with the store's version and build number.
(cd "$app_dir" && EXACT_VERSION="$version" EXACT_BUILD_NUMBER="$build" \
  bun exact.mjs ios --device --archive "$work/unsigned.ipa" --unsigned)

# 2. an xcode archive around the app. the app's signature gets the team-prefixed
# application-identifier, which the app store profile checks; exact's unsigned build
# writes the bare bundle id.
archive="$work/Mux.xcarchive"
mkdir -p "$archive/Products/Applications" "$archive/dSYMs"
unzip -q "$work/unsigned.ipa" -d "$work/ipa"
cp -R "$work/ipa/Payload/"*.app "$archive/Products/Applications/"
apps=("$archive/Products/Applications/"*.app)
[ "${#apps[@]}" -eq 1 ] && [ -d "${apps[0]}" ] || { echo "expected one archived app" >&2; exit 1; }
app_path="${apps[0]##*/}"
if [ -d "$work/unsigned.dSYM" ]; then cp -R "$work/unsigned.dSYM" "$archive/dSYMs/$app_path.dSYM"; fi
# each embedded framework's dsym (<framework>.framework.dSYM), or the symbol upload names it as missing.
if [ -d "$work/unsigned.dSYMs" ]; then cp -R "$work/unsigned.dSYMs/" "$archive/dSYMs/"; fi

# package and sign the nested extension first, then the containing app. no device is installed.
"$here/add-notification-extension.sh" --store "$archive/dSYMs" "$archive/Products/Applications/$app_path"

cat > "$archive/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>ApplicationProperties</key><dict>
<key>ApplicationPath</key><string>Applications/$app_path</string>
<key>Architectures</key><array><string>arm64</string></array>
<key>CFBundleIdentifier</key><string>$bundle</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>$build</string>
<key>SigningIdentity</key><string>Ad Hoc</string>
<key>Team</key><string>$team</string>
</dict>
<key>ArchiveVersion</key><integer>2</integer>
<key>CreationDate</key><date>$(date -u +%Y-%m-%dT%H:%M:%SZ)</date>
<key>Name</key><string>${app_path%.app}</string>
<key>SchemeName</key><string>${app_path%.app}</string>
</dict></plist>
EOF

# 3. xcode signs for the app store and exports or uploads.
cat > "$work/export.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>app-store-connect</string>
<key>teamID</key><string>$team</string>
<key>signingStyle</key><string>automatic</string>
<key>destination</key><string>$destination</string>
<key>uploadSymbols</key><true/>
<key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
EOF
if [ "$archive_only" = true ]; then
  echo "archive: $archive"
  echo "export options: $work/export.plist"
  exit 0
fi

xcodebuild -exportArchive -archivePath "$archive" -exportPath "$work/out" \
  -exportOptionsPlist "$work/export.plist" -allowProvisioningUpdates

if [ "$destination" = "upload" ]; then
  echo "uploaded $version ($build). app store connect processes it for a few minutes, then it shows in testflight."
else
  echo "signed: $work/out/$(cd "$work/out" && ls *.ipa)"
fi
