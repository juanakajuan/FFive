#!/bin/sh
# Archives FFive from the committed HEAD and uploads it to TestFlight.
#
#   scripts/release-testflight.sh           archive and upload
#   scripts/release-testflight.sh --local   archive and export an .ipa to build/release, no upload
#   scripts/release-testflight.sh --version 1.1
#                                           commit MARKETING_VERSION = 1.1 first, then release
#
# The build number is a UTC timestamp on every run. The user-facing version only
# changes with --version; bump it for a meaningful release, and always after a
# version is approved on the App Store, which then rejects new builds of it.
#
# Auth: set ASC_KEY_ID and ASC_ISSUER_ID to use an App Store Connect API key
# (ASC_KEY_PATH defaults to ~/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8).
# Without them, xcodebuild uses the Apple ID signed in to Xcode > Settings > Accounts.
set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
project="$root/FFive.xcodeproj/project.pbxproj"
team="$(sed -n 's/.*DEVELOPMENT_TEAM = \(.*\);/\1/p' "$project" | head -1)"
usage="usage: $0 [--local] [--version X.Y[.Z]]"

destination=upload
new_version=""
while [ $# -gt 0 ]; do
    case "$1" in
        --local) destination=export ;;
        --version)
            [ $# -ge 2 ] || { echo "$usage" >&2; exit 2; }
            new_version="$2"
            shift
            ;;
        *) echo "$usage" >&2; exit 2 ;;
    esac
    shift
done

if [ -n "$new_version" ] && ! echo "$new_version" | grep -Eq '^[0-9]+(\.[0-9]+){0,2}$'; then
    echo "error: --version must look like 1.1 or 1.1.2, got '$new_version'" >&2
    exit 2
fi

if [ -n "$(git -C "$root" status --porcelain)" ]; then
    echo "error: working tree is dirty; commit first so the build matches a commit" >&2
    exit 1
fi

if [ -n "$new_version" ]; then
    sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $new_version;/" "$project"
    if [ -n "$(git -C "$root" status --porcelain)" ]; then
        git -C "$root" commit -q -m "chore: bump version to $new_version" -- "$project"
        echo "==> committed version $new_version"
    else
        echo "==> version is already $new_version"
    fi
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
