#!/bin/sh
# Archives FFive from the committed HEAD and uploads it to TestFlight.
#
#   scripts/release-testflight.sh           archive and upload
#   scripts/release-testflight.sh --local   archive and export an .ipa to build/release, no upload
#
# Auth: set ASC_KEY_ID and ASC_ISSUER_ID to use an App Store Connect API key
# (ASC_KEY_PATH defaults to ~/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8).
# Without them, xcodebuild uses the Apple ID signed in to Xcode > Settings > Accounts.
set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
team="$(sed -n 's/.*DEVELOPMENT_TEAM = \(.*\);/\1/p' "$root/FFive.xcodeproj/project.pbxproj" | head -1)"

destination=upload
case "${1:-}" in
    "") ;;
    --local) destination=export ;;
    *) echo "usage: $0 [--local]" >&2; exit 2 ;;
esac

if [ -n "$(git -C "$root" status --porcelain)" ]; then
    echo "error: working tree is dirty; commit first so the build matches a commit" >&2
    exit 1
fi

auth=""
if [ -n "${ASC_KEY_ID:-}" ]; then
    : "${ASC_ISSUER_ID:?set ASC_ISSUER_ID alongside ASC_KEY_ID}"
    key="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8}"
    [ -f "$key" ] || { echo "error: no API key at $key" >&2; exit 1; }
    auth="-authenticationKeyPath $key -authenticationKeyID $ASC_KEY_ID -authenticationKeyIssuerID $ASC_ISSUER_ID"
fi

# UTC timestamp: always increasing, and a retry after a failed upload gets a fresh number.
build="$(date -u +%Y%m%d%H%M)"
commit="$(git -C "$root" rev-parse --short HEAD)"
out="$root/build/release"
archive="$out/FFive-$build.xcarchive"
mkdir -p "$out"

options="$out/ExportOptions.plist"
cat > "$options" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>$destination</string>
    <key>teamID</key><string>$team</string>
    <key>signingStyle</key><string>automatic</string>
    <key>manageAppVersionAndBuildNumber</key><false/>
    <key>uploadSymbols</key><true/>
</dict>
</plist>
EOF

echo "==> archiving build $build from $commit"
# shellcheck disable=SC2086
xcodebuild archive \
    -project "$root/FFive.xcodeproj" \
    -scheme FFive \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$archive" \
    -allowProvisioningUpdates $auth \
    CURRENT_PROJECT_VERSION="$build" \
    > "$out/archive-$build.log" 2>&1 \
    || { tail -40 "$out/archive-$build.log" >&2; echo "error: archive failed; full log at $out/archive-$build.log" >&2; exit 1; }

echo "==> exporting ($destination)"
# shellcheck disable=SC2086
xcodebuild -exportArchive \
    -archivePath "$archive" \
    -exportOptionsPlist "$options" \
    -exportPath "$out/export-$build" \
    -allowProvisioningUpdates $auth \
    > "$out/export-$build.log" 2>&1 \
    || { tail -40 "$out/export-$build.log" >&2; echo "error: export failed; full log at $out/export-$build.log" >&2; exit 1; }

version="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleShortVersionString' "$archive/Info.plist")"
if [ "$destination" = upload ]; then
    echo "==> uploaded FFive $version ($build) from $commit; it appears in TestFlight once App Store Connect finishes processing"
else
    echo "==> exported FFive $version ($build) from $commit to $out/export-$build"
fi
