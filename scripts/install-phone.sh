#!/usr/bin/env bash
# Build a Release archive of Pr0gramm, export it with the development method, and install it on
# a connected iPhone. Reads the signing team from DEVELOPMENT_TEAM; see README.md, "Install on a
# device".
#
#   scripts/install-phone.sh [--dry-run] [device name or identifier]
#
# Logs and every generated file land under build/, which git ignores.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
README_HINT='see README.md, section "Install on a device"'

dry_run=0
device=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    -h|--help)
      sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "install-phone: unknown option $arg" >&2
      exit 2
      ;;
    *)
      if [ -n "$device" ]; then
        echo "install-phone: only one device argument is accepted" >&2
        exit 2
      fi
      device="$arg"
      ;;
  esac
done

if [ -z "${DEVELOPMENT_TEAM:-}" ]; then
  echo "install-phone: DEVELOPMENT_TEAM is not set; $README_HINT." >&2
  exit 1
fi

cd "$IOS_DIR"
mkdir -p build
log="$IOS_DIR/build/install-phone-$(date +%Y%m%d-%H%M%S).log"
export_plist="$IOS_DIR/build/ExportOptions.plist"
archive="build/Pr0gramm.xcarchive"
export_dir="build/export"
ipa="$export_dir/Pr0gramm.ipa"

say() { printf '%s\n' "$*" | tee -a "$log"; }

# Run a command in ios/, mirroring its output to the log; on failure, name the log and exit.
run() {
  local step="$1"; shift
  say "==> $step"
  say "+ $(printf '%q ' "$@")"
  if [ "$dry_run" = 1 ]; then
    return 0
  fi
  if ! "$@" 2>&1 | tee -a "$log"; then
    echo "install-phone: $step failed; log: $log" >&2
    exit 1
  fi
}

# Print the connected physical iPhones as "identifier<TAB>name", one per line.
connected_iphones() {
  local json
  json="$(mktemp -t install-phone-devices)"
  xcrun devicectl list devices --json-output "$json" >/dev/null 2>&1 || {
    echo "install-phone: xcrun devicectl list devices failed; is Xcode selected?" >&2
    rm -f "$json"
    return 1
  }
  python3 - "$json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
for d in data.get("result", {}).get("devices", []):
    # The devicectl JSON moved from properties.{hardware,connection} to top-level
    # hardwareProperties / connectionProperties / deviceProperties; read either.
    p = d.get("properties", {})
    hw = d.get("hardwareProperties") or p.get("hardware", {})
    conn = d.get("connectionProperties") or p.get("connection", {})
    if hw.get("reality") != "physical" or hw.get("deviceType") != "iPhone":
        continue
    if conn.get("state") != "connected" and conn.get("pairingState") != "paired":
        continue
    name = d.get("deviceProperties", {}).get("name") or p.get("name", "")
    print(f"{d.get('identifier', '')}\t{name}")
PY
  rm -f "$json"
}

if [ -z "$device" ]; then
  say "==> Looking for a connected iPhone"
  say "+ xcrun devicectl list devices"
  iphones="$(connected_iphones)"
  count=0
  [ -n "$iphones" ] && count="$(printf '%s\n' "$iphones" | wc -l | tr -d ' ')"
  if [ "$count" = 0 ]; then
    echo "install-phone: no connected iPhone; plug one in or pass a device name or identifier." >&2
    exit 1
  elif [ "$count" != 1 ]; then
    echo "install-phone: several iPhones are connected; pass one of:" >&2
    printf '%s\n' "$iphones" | awk -F'\t' '{ printf "  %s  (%s)\n", $1, $2 }' >&2
    exit 1
  fi
  device="${iphones%%$'\t'*}"
  say "    using ${iphones#*$'\t'} ($device)"
fi

say "==> Writing $export_plist"
cat > "$export_plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>development</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>${DEVELOPMENT_TEAM}</string>
	<key>destination</key>
	<string>export</string>
	<key>compileBitcode</key>
	<false/>
	<key>stripSwiftSymbols</key>
	<true/>
	<key>thinning</key>
	<string>&lt;none&gt;</string>
</dict>
</plist>
PLIST
plutil -lint "$export_plist" >/dev/null

if [ "$dry_run" = 1 ]; then
  say "==> Dry run; the commands below run from $IOS_DIR"
fi
run "Generating the project with team $DEVELOPMENT_TEAM" \
  xcodegen generate
run "Archiving the Release build" \
  xcodebuild -project Pr0gramm.xcodeproj -scheme Pr0gramm -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$archive" -allowProvisioningUpdates archive
run "Exporting the archive" \
  xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$export_plist" \
    -exportPath "$export_dir" -allowProvisioningUpdates
run "Installing on $device" \
  xcrun devicectl device install app --device "$device" "$ipa"

say "==> Done: $IOS_DIR/$ipa"
say "    log: $log"
