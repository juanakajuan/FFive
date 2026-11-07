#!/bin/sh
# Writes FFive/Changelog.json from the git history. Each "chore: bump version to X" commit closes
# release X; a commit belongs to the first release whose bump commit contains it, so the oldest
# release also holds everything before it.
#
#   scripts/changelog.sh               releases already cut
#   scripts/changelog.sh --next 1.5    also the commits since the last bump, as release 1.5 dated today
set -eu
cd "$(dirname "$0")/.."

next=""
if [ "${1:-}" = "--next" ]; then
    next="${2:?usage: $0 [--next X.Y[.Z]]}"
fi

stream="$(mktemp)"
trap 'rm -f "$stream"' EXIT

commits() { git log --no-merges --format="C%x09%ad%x09%s" --date=short "$@"; }

# Bump commits, newest first: "<sha> <version> <date>".
bumps="$(git log --format='%H %ad %s' --date=short --grep='^chore: bump version to ' \
    | awk '{ print $1, $NF, $2 }')"

if [ -n "$next" ]; then
    printf 'R\t%s\t%s\n' "$next" "$(date +%Y-%m-%d)" >> "$stream"
    if [ -n "$bumps" ]; then
        commits "$(echo "$bumps" | head -1 | cut -d' ' -f1)..HEAD" >> "$stream"
    else
        commits HEAD >> "$stream"
    fi
fi

echo "$bumps" | while read -r sha version date; do
    [ -n "$sha" ] || continue
    older="$(echo "$bumps" | awk -v s="$sha" 'found { print $1; exit } $1 == s { found = 1 }')"
    printf 'R\t%s\t%s\n' "$version" "$date" >> "$stream"
    if [ -n "$older" ]; then commits "$older..$sha" >> "$stream"; else commits "$sha" >> "$stream"; fi
done

swift run --quiet --package-path FFiveCore ChangelogGen < "$stream" > FFive/Changelog.json
echo "changelog: wrote FFive/Changelog.json"
