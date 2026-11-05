#!/bin/sh
# --trunk compiles out the store.log side so these probe files also run in a checkout that predates Store.log.
set -eu
cd "$(dirname "$0")/.."
flags=""
[ "${1:-}" = "--trunk" ] && flags="-Xswiftc -DTRUNK_WRITE"
swift run --quiet --package-path FFiveCore $flags PerfProbe
