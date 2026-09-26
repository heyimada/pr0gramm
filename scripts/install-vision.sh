#!/usr/bin/env bash
# Build, export, and install the native Release app on a paired Apple Vision Pro over Wi-Fi.
# Uses DEVELOPMENT_TEAM and the signing account configured in Xcode.
#
#   scripts/install-vision.sh [--dry-run] [device name or identifier]
#
# Keep the headset awake and unlocked. Logs and exports live in build/vision/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
dry_run=0
device=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    -h|--help)
      sed -n '2,7p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    -*) echo "install-vision: unknown option $arg" >&2; exit 2 ;;
    *)
      if [ -n "$device" ]; then
        echo "install-vision: only one device argument is accepted" >&2
        exit 2
      fi
      device="$arg" ;;
  esac
done

if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
  echo "install-vision: set DEVELOPMENT_TEAM to your Xcode signing team ID; see README.md." >&2
  exit 1
fi

cd "$IOS_DIR"
mkdir -p build/vision
run_dir="$(mktemp -d "$IOS_DIR/build/vision/install-XXXXXX")"
log="$run_dir/install.log"
archive="$run_dir/Pr0gramm-visionOS.xcarchive"
export_dir="$run_dir/export"
export_plist="$run_dir/ExportOptions.plist"
ipa="$export_dir/Pr0gramm.ipa"
app="$run_dir/unpacked/Payload/Pr0gramm.app"
say() { printf '%s\n' "$*" | tee -a "$log"; }
run() {
  local step="$1"; shift
  say "==> $step"
  say "+ $(printf '%q ' "$@")"
  if [ "$dry_run" = 1 ]; then return 0; fi
  if ! "$@" 2>&1 | tee -a "$log"; then
    echo "install-vision: $step failed; log: $log" >&2
    exit 1
  fi
}

say "==> Looking for a connected Apple Vision Pro"
if ! xcrun devicectl list devices --json-output "$run_dir/devices.json" >> "$log" 2>&1; then
  echo "install-vision: device discovery failed; log: $log" >&2
  exit 1
fi
selection="$(python3 - "$run_dir/devices.json" "$device" <<'PY'
import json, sys

def normalized(value):
    return ' '.join(value.split())

requested = normalized(sys.argv[2])
candidates = []
for device in json.load(open(sys.argv[1])).get('result', {}).get('devices', []):
    # The devicectl JSON moved from properties.{hardware,connection,state} to top-level
    # hardwareProperties / connectionProperties / deviceProperties; read either.
    props = device.get('properties', {})
    hardware = device.get('hardwareProperties') or props.get('hardware', {})
    connection = device.get('connectionProperties') or props.get('connection', {})
    if hardware.get('reality') != 'physical' or hardware.get('platform') != 'visionOS':
        continue
    # A paired headset that is awake is enough: `devicectl device install` opens the tunnel itself.
    if connection.get('state') != 'connected' and connection.get('pairingState') != 'paired':
        continue
    identifier = device.get('identifier', '')
    udid = hardware.get('udid', '')
    name = device.get('deviceProperties', {}).get('name') or props.get('state', {}).get('name', '')
    if requested and requested not in {normalized(v) for v in [identifier, udid, name]}:
        continue
    if identifier and udid:
        candidates.append((identifier, udid, name))
if not candidates:
    sys.exit('install-vision: no matching connected Vision Pro. Keep it awake and unlocked on the same Wi-Fi as your Mac, and check Xcode Device Hub.')
if len(candidates) > 1:
    for identifier, udid, name in candidates:
        print(f'  {name} ({udid})', file=sys.stderr)
    sys.exit('install-vision: several headsets match; pass a device name or identifier.')
print('\t'.join(candidates[0]))
PY
)"
IFS=$'\t' read -r device udid device_name <<< "$selection"
say "    using $device_name ($udid)"

python3 - "$export_plist" <<'PY'
import os, plistlib, sys
with open(sys.argv[1], 'wb') as output:
    plistlib.dump({
        'method': 'debugging',
        'signingStyle': 'automatic',
        'teamID': os.environ['DEVELOPMENT_TEAM'],
        'destination': 'export',
        'stripSwiftSymbols': True,
        'thinning': '<none>',
    }, output)
PY

if [ "$dry_run" = 1 ]; then
  say "==> Dry run; no build, signing, or installation will run"
fi
run "Generating the project" xcodegen generate
# Archive signing can reuse a profile that excludes the headset; a device build refreshes it first.
run "Preparing signing for the selected Vision Pro" \
  xcodebuild -project Pr0gramm.xcodeproj -scheme Pr0gramm -configuration Release \
    -destination "platform=visionOS,id=$udid" -derivedDataPath "$IOS_DIR/build/vision/DerivedData" \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
run "Archiving Release for Vision Pro" \
  xcodebuild -project Pr0gramm.xcodeproj -scheme Pr0gramm -configuration Release \
    -destination "platform=visionOS,id=$udid" -archivePath "$archive" \
    -derivedDataPath "$IOS_DIR/build/vision/DerivedData" \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration archive
run "Exporting the signed app" \
  xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$export_plist" \
    -exportPath "$export_dir" -allowProvisioningUpdates -allowProvisioningDeviceRegistration
run "Unpacking the app for devicectl" ditto -x -k "$ipa" "$run_dir/unpacked"
run "Installing on $device_name" xcrun devicectl device install app --device "$device" "$app"

if [ "$dry_run" = 1 ]; then
  say "==> Dry run complete"
else
  say "==> Installed pr0gramm on $device_name. Open it from Home View."
  say "    archive export: $ipa"
fi
say "    log: $log"
