#!/bin/sh
# --trunk prints the numbers without enforcing the budget, so the same probe reads a baseline in an older checkout.
set -eu
cd "$(dirname "$0")/.."
flags=""
[ "${1:-}" = "--trunk" ] && flags="--no-budget"
swift run --quiet --package-path FFiveCore PerfProbe $flags
