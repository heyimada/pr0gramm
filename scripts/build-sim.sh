#!/bin/zsh
# Builds the app for the iOS Simulator into build/dd and installs it on the simulator named by
# SIMULATOR (default "iPhone Duo"), booting it if needed. Prints only errors and the final status.
set -euo pipefail
root=${0:A:h:h}
device=${SIMULATOR:-iPhone Duo}
cd $root
xcodegen generate -q
app=build/dd/Build/Products/Debug-iphonesimulator/Pr0gramm.app
if ! xcodebuild -project Pr0gramm.xcodeproj -scheme Pr0gramm -configuration Debug \
    -destination "generic/platform=iOS Simulator" -derivedDataPath build/dd build -quiet > build/build-sim.log 2>&1; then
    grep -E "error:" build/build-sim.log | sort -u >&2
    echo "build failed, full log in build/build-sim.log" >&2
    exit 1
fi
udid=$(xcrun simctl list devices available | grep -F "    $device (" | head -1 | grep -oE '[0-9A-F-]{36}')
xcrun simctl bootstatus $udid -b > /dev/null
xcrun simctl install $udid $app
echo "installed on $device ($udid)"
