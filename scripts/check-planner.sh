#!/bin/sh
set -eu
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
swiftc -parse-as-library -o "$out/planner-checks" \
    "$root/WorkoutApp/Domain.swift" \
    "$root/WorkoutApp/Progression.swift" \
    "$root/WorkoutApp/ExerciseCatalog.swift" \
    "$root/WorkoutApp/Models.swift" \
    "$root/WorkoutApp/MesoPlanner.swift" \
    "$root/scripts/PlannerChecks.swift"
"$out/planner-checks"
