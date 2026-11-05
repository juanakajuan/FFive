#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
release="-c release -Xswiftc -enable-testing"
if [ "${1:-}" = "--trunk" ]; then
    rev=$(git rev-parse --verify "${2:?usage: perf-probe.sh [--trunk <rev>]}^{commit}")
    dir="${TMPDIR:-/tmp}/ffive-perf-probe-$rev"
    mkdir -p "$dir"
    git archive "$rev" FFiveCore | tar -x -C "$dir"
    cp -p FFiveCore/Sources/PerfProbe/PerfProbe.swift "$dir/FFiveCore/Sources/PerfProbe/PerfProbe.swift"
    echo "perf-probe: FFiveCore at $rev"
    swift run --quiet $release --package-path "$dir/FFiveCore" PerfProbe --no-budget
else
    swift run --quiet $release --package-path FFiveCore PerfProbe
fi
