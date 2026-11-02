#!/bin/sh
set -eu
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
swiftc -parse-as-library -o "$out/engine-checks" \
    "$root/WorkoutApp/Domain.swift" \
    "$root/WorkoutApp/Progression.swift" \
    "$root/scripts/EngineChecks.swift"
"$out/engine-checks"
