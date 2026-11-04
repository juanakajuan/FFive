#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
triple=arm64-apple-ios17.0-simulator
files="$(mktemp)"
log="$(mktemp)"
trap 'rm -f "$files" "$log"' EXIT
swift build --package-path FFiveCore --triple "$triple" --sdk "$sdk" --target FFiveCore > "$log" 2>&1 \
    || { awk 'length < 400' "$log"; echo "typecheck: FFiveCore failed to build for iOS"; exit 1; }
find FFive -name '*.swift' | sort > "$files"
xcrun swiftc -typecheck -swift-version 5 -target "$triple" -sdk "$sdk" \
    -I FFiveCore/.build/out/Products/Debug-iphonesimulator @"$files"
echo "typecheck: ok, $(wc -l < "$files" | tr -d ' ') app files against FFiveCore"
