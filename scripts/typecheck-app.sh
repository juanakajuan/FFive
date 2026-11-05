#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
files="$(mktemp)"
trap 'rm -f "$files"' EXIT
find FFive -name '*.swift' | sort > "$files"
xcrun swiftc -typecheck -swift-version 5 -target arm64-apple-ios17.0-simulator \
    -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" @"$files"
echo "typecheck: ok, $(wc -l < "$files" | tr -d ' ') files"
