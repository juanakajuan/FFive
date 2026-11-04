#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift run --quiet --package-path FFiveCore PerfProbe
