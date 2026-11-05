#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
paths="FFive FFiveCore .claude/skills/verify-ffive/harness"

case "${1:-}" in
    "") swift format format --in-place --recursive --parallel $paths ;;
    --lint) swift format lint --strict --recursive --parallel $paths && echo "swift-format: ok" ;;
    *) echo "usage: format.sh [--lint]" >&2; exit 2 ;;
esac
