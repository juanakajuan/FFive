#!/bin/sh
# Archives FFive from the committed HEAD and uploads it to TestFlight.
#
#   scripts/release-testflight.sh --version 1.1
#                                           set MARKETING_VERSION = 1.1, archive and upload, then commit it
#   scripts/release-testflight.sh --bump patch|minor|major
#                                           bump MARKETING_VERSION (1.0 -> 1.0.1, 1.1 or 2.0), upload, then commit
#   scripts/release-testflight.sh --local   archive and export an .ipa to build/release, no upload
#
# Every upload carries a new release number: --version or --bump is required unless
# --local. The version change also rewrites FFive/Changelog.json from the git history
# (scripts/changelog.sh), so the build's What's New lists every feat, fix and perf commit since the last release.
# Both files are committed only once the upload (or --local export) succeeds; a failed run
# restores them, so rerun the same command. The build number is a UTC timestamp on every run.
#
# An upload first runs scripts/cloudkit-schema.sh, which stops it when CloudKit Production lacks a
# field this build syncs. Pass --skip-cloudkit-check to upload anyway.
#
# Auth: set ASC_KEY_ID and ASC_ISSUER_ID to use an App Store Connect API key
# (ASC_KEY_PATH defaults to ~/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8).
# Without them, xcodebuild uses the Apple ID signed in to Xcode > Settings > Accounts.
set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
project="$root/FFive.xcodeproj/project.pbxproj"
team="$(sed -n 's/.*DEVELOPMENT_TEAM = \(.*\);/\1/p' "$project" | head -1)"
usage="usage: $0 --version X.Y[.Z] | --bump patch|minor|major | --local [--skip-cloudkit-check]"

destination=upload
new_version=""
bump=""
cloudkit_check=yes
while [ $# -gt 0 ]; do
    case "$1" in
        --local) destination=export ;;
        --skip-cloudkit-check) cloudkit_check=no ;;
        --version)
            [ $# -ge 2 ] || { echo "$usage" >&2; exit 2; }
            new_version="$2"
            shift
            ;;
        --bump)
            [ $# -ge 2 ] || { echo "$usage" >&2; exit 2; }
            case "$2" in patch|minor|major) bump="$2" ;; *) echo "$usage" >&2; exit 2 ;; esac
            shift
            ;;
        *) echo "$usage" >&2; exit 2 ;;
    esac
    shift
done

if [ -n "$new_version" ] && [ -n "$bump" ]; then
    echo "error: pass --version or --bump, not both" >&2
    exit 2
fi

if [ "$destination" = upload ] && [ -z "$new_version" ] && [ -z "$bump" ]; then
    echo "error: every upload needs a release number; pass --version X.Y[.Z] or --bump patch|minor|major" >&2
    echo "$usage" >&2
    exit 2
fi

if [ -n "$bump" ]; then
    current="$(sed -n 's/.*MARKETING_VERSION = \(.*\);/\1/p' "$project" | head -1)"
    new_version="$(echo "$current" | awk -F. -v part="$bump" '{
        major = $1; minor = (NF >= 2 ? $2 : 0); patch = (NF >= 3 ? $3 : 0)
        if (part == "major") { major++; minor = 0; patch = 0 }
        else if (part == "minor") { minor++; patch = 0 }
        else { patch++ }
        if (patch > 0) print major "." minor "." patch; else print major "." minor
    }')"
    echo "==> bumping $bump: $current -> $new_version"
fi

if [ -n "$new_version" ] && ! echo "$new_version" | grep -Eq '^[0-9]+(\.[0-9]+){0,2}$'; then
    echo "error: --version must look like 1.1 or 1.1.2, got '$new_version'" >&2
    exit 2
fi

if [ "$destination" = upload ] && [ "$cloudkit_check" = yes ]; then
    "$root/scripts/cloudkit-schema.sh" production
fi

if [ -n "$(git -C "$root" status --porcelain)" ]; then
    echo "error: working tree is dirty; commit first so the build matches a commit" >&2
    exit 1
fi

changelog="$root/FFive/Changelog.json"
commit="$(git -C "$root" rev-parse --short HEAD)"
if [ -n "$new_version" ]; then
    # The version change stays uncommitted until the build ships. A failed run puts both
    # files back, so the same --bump or --version can simply be rerun.
    restore() { git -C "$root" checkout -q -- "$project" "$changelog"; }
    trap restore EXIT
    trap 'exit 130' INT TERM
    sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $new_version;/" "$project"
    if [ -z "$(git -C "$root" status --porcelain)" ]; then
        echo "error: version is already $new_version; every upload needs a new release number" >&2
        exit 2
    fi
    "$root/scripts/changelog.sh" --next "$new_version"
    commit="$commit + version $new_version"
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
if [ -n "$new_version" ]; then
    git -C "$root" commit -q -m "chore: bump version to $new_version" -- "$project" "$changelog"
    trap - EXIT INT TERM
    commit="$(git -C "$root" rev-parse --short HEAD)"
    echo "==> committed version $new_version and its changelog as $commit"
fi
if [ "$destination" = upload ]; then
    echo "==> uploaded FFive $version ($build) from $commit; it appears in TestFlight once App Store Connect finishes processing"
else
    echo "==> exported FFive $version ($build) from $commit to $out/export-$build"
fi
