#!/bin/sh
set -eu
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
swiftc -parse-as-library -o "$out/perf-probe" \
    "$root/FFive/Domain.swift" \
    "$root/FFive/Progression.swift" \
    "$root/FFive/ExerciseCatalog.swift" \
    "$root/FFive/Models.swift" \
    "$root/FFive/MesoPlanner.swift" \
    "$root/scripts/perf-probe.swift"
"$out/perf-probe"
