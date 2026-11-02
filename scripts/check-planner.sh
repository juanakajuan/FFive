#!/bin/sh
set -eu
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
swiftc -parse-as-library -o "$out/planner-checks" \
    "$root/FFive/Domain.swift" \
    "$root/FFive/Progression.swift" \
    "$root/FFive/ExerciseCatalog.swift" \
    "$root/FFive/Models.swift" \
    "$root/FFive/MesoPlanner.swift" \
    "$root/scripts/PlannerChecks.swift"
"$out/planner-checks"
