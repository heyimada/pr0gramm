#!/bin/zsh
# Compiles the app's sources with scripts/verify/pin/main.swift for the iOS Simulator, runs the
# result on a simulator and diffs its output against pin.baseline.txt.
#
#   scripts/verify/pin.sh            compare against the baseline
#   scripts/verify/pin.sh --record   overwrite the baseline
#
# SIMULATOR picks the device (default: the iPhone Duo); it is booted if needed.
set -euo pipefail

root=${0:A:h:h:h}
here=${0:A:h}
out=$root/build/pin
device=${SIMULATOR:-iPhone Duo}
mkdir -p $out

sources=(${(f)"$(grep -rL '^@main' $root/Pr0gramm --include='*.swift')"})
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun swiftc -target arm64-apple-ios26.0-simulator -sdk $sdk \
    -swift-version 6 -default-isolation MainActor \
    -enable-upcoming-feature NonisolatedNonsendingByDefault -enable-upcoming-feature InferIsolatedConformances \
    -suppress-warnings -o $out/pin $sources $here/pin/main.swift

udid=$(xcrun simctl list devices available | grep -F "$device (" | head -1 | grep -oE '[0-9A-F-]{36}')
xcrun simctl bootstatus $udid -b > /dev/null
xcrun simctl spawn $udid $out/pin > $out/pin.txt

if [[ ${1:-} == --record ]]; then
    cp $out/pin.txt $here/pin.baseline.txt
    echo "recorded $(wc -l < $here/pin.baseline.txt | tr -d ' ') lines"
elif diff -u $here/pin.baseline.txt $out/pin.txt; then
    echo "pin: no behavior change ($(wc -l < $out/pin.txt | tr -d ' ') lines)"
else
    echo "pin: behavior changed" >&2
    exit 1
fi
