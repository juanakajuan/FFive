#!/bin/sh
# Checks that a CloudKit environment has every field in cloudkit/schema-fields.txt.
#
#   scripts/cloudkit-schema.sh            check Production, the environment TestFlight and App Store builds use
#   scripts/cloudkit-schema.sh development
#
# A TestFlight build that writes a field Production lacks fails to sync with "Failed to modify some
# records". Debug builds push new fields to Development on launch; deploy them to Production with
# Deploy Schema Changes in the CloudKit Console.
#
# Auth: a CloudKit management token saved with `xcrun cktool save-token --type management`.
set -eu
# comm needs both lists in one collation; schema-fields.txt is sorted bytewise.
export LC_ALL=C

root="$(cd "$(dirname "$0")/.." && pwd)"
environment="${1:-production}"
container="iCloud.com.juanix.FFive"
team="$(sed -n 's/.*DEVELOPMENT_TEAM = \(.*\);/\1/p' "$root/FFive.xcodeproj/project.pbxproj" | head -1)"
console="https://icloud.developer.apple.com/dashboard/database/teams/$team/containers/$container/environments/DEVELOPMENT/deploy"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

xcrun cktool export-schema --team-id "$team" --container-id "$container" \
    --environment "$environment" --output-file "$tmp/schema.ckdb" > "$tmp/cktool.log" 2>&1 \
    || { cat "$tmp/cktool.log" >&2; echo "error: could not export the $environment schema; save a token with: xcrun cktool save-token --type management" >&2; exit 1; }

awk '
    /RECORD TYPE/ { type = $3; next }
    /^[[:space:]]*\);/ { type = ""; next }
    type != "" && $1 ~ /^CD_/ { print type "." $1 }
' "$tmp/schema.ckdb" | sort > "$tmp/actual.txt"

missing="$(comm -23 "$root/cloudkit/schema-fields.txt" "$tmp/actual.txt")"
if [ -n "$missing" ]; then
    echo "error: CloudKit $environment is missing fields this build syncs:" >&2
    echo "$missing" | sed 's/^/  /' >&2
    if [ "$environment" = production ]; then
        echo "Run a debug build signed in to iCloud to push them to Development, then deploy them:" >&2
        echo "  $console" >&2
    else
        echo "Run a debug build on a device or simulator signed in to iCloud; it pushes them on launch." >&2
    fi
    exit 1
fi
echo "CloudKit $environment has every field in cloudkit/schema-fields.txt"
