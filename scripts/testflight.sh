#!/usr/bin/env bash
# Archive Pr0gramm for iOS and/or visionOS and upload it to App Store Connect for TestFlight.
# Reads the signing team from DEVELOPMENT_TEAM and uploads with the Apple ID signed in to Xcode;
# see README.md, "TestFlight". The app record must already exist in App Store Connect.
#
#   scripts/testflight.sh [--dry-run] [--no-upload] [ios|visionos|all]   (default: all)
#
# Every run gets a fresh build number (yyyymmdd.HHMM). Logs and archives land under build/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
README_HINT='see README.md, section "TestFlight"'

dry_run=0
upload=1
platforms="ios visionos"
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    --no-upload) upload=0 ;;
    ios|visionos) platforms="$arg" ;;
    all) platforms="ios visionos" ;;
    -h|--help)
      sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "testflight: unknown argument $arg" >&2
      exit 2
      ;;
  esac
done

if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
  echo "testflight: DEVELOPMENT_TEAM is not set; $README_HINT." >&2
  exit 1
fi

cd "$IOS_DIR"
mkdir -p build/testflight
build_number="$(date +%Y%m%d.%H%M)"
log="$IOS_DIR/build/testflight/testflight-$build_number.log"
export_plist="$IOS_DIR/build/testflight/ExportOptions.plist"

say() { printf '%s\n' "$*" | tee -a "$log"; }

# Run a command, mirroring its output to the log; on failure, name the log and exit.
run() {
  local step="$1"; shift
  say "==> $step"
  say "+ $(printf '%q ' "$@")"
  if [ "$dry_run" = 1 ]; then
    return 0
  fi
  if ! "$@" 2>&1 | tee -a "$log"; then
    echo "testflight: $step failed; log: $log" >&2
    exit 1
  fi
}

say "==> Writing $export_plist"
cat > "$export_plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>upload</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>${DEVELOPMENT_TEAM}</string>
	<key>uploadSymbols</key>
	<true/>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
</dict>
</plist>
PLIST
plutil -lint "$export_plist" >/dev/null

if [ "$dry_run" = 1 ]; then
  say "==> Dry run; the commands below run from $IOS_DIR"
fi
run "Generating the project with team $DEVELOPMENT_TEAM" \
  xcodegen generate

for platform in $platforms; do
  case "$platform" in
    ios) destination="generic/platform=iOS" ;;
    visionos) destination="generic/platform=visionOS" ;;
  esac
  archive="build/testflight/Pr0gramm-$platform-$build_number.xcarchive"
  run "Archiving the $platform Release build $build_number" \
    xcodebuild -project Pr0gramm.xcodeproj -scheme Pr0gramm -configuration Release \
      -destination "$destination" -archivePath "$archive" \
      CURRENT_PROJECT_VERSION="$build_number" -allowProvisioningUpdates archive
  if [ "$upload" = 1 ]; then
    run "Uploading the $platform build to App Store Connect" \
      xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$export_plist" \
        -exportPath "build/testflight/export-$platform" -allowProvisioningUpdates
  fi
done

say "==> Done: build $build_number ($platforms)"
if [ "$upload" = 1 ]; then
  say "    Processing takes a few minutes; the build then shows up under TestFlight in App Store Connect."
fi
say "    log: $log"
