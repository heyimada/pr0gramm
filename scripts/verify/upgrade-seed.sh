#!/bin/zsh
# Installs an app build fresh and writes every saved key plus one download in the formats the
# original app stores, so scripts/verify/upgrade-probe.sh can compare builds over the same data.
#
#   scripts/verify/upgrade-seed.sh <simulator udid> <path to Pr0gramm.app>
#
# Typical run: seed with the original build, probe, install the new build over it (simctl
# install, no uninstall), probe again, diff the two probe outputs and the stored data.
set -euo pipefail
udid=$1
app=$2
root=${0:A:h:h:h}

xcrun simctl bootstatus $udid -b > /dev/null
xcrun simctl uninstall $udid de.azula.pr0gramm || true
xcrun simctl install $udid $app
container=$(xcrun simctl get_app_container $udid de.azula.pr0gramm data)
mkdir -p "$container/Library/Preferences" "$container/Documents/Downloads"

python3 - "$container/Library/Preferences/de.azula.pr0gramm.plist" <<'EOF'
import plistlib, sys
plistlib.dump({
    "customFeeds": b'[{"id":"8F718422-5E07-435B-B28A-DBA584288632","name":"Katzen","tags":"kadse -s\xc3\xbc\xc3\x9fvieh","stream":"new","flags":0,"isProtected":false}]',
    "defaultFeed": b'{"custom":{"_0":"8F718422-5E07-435B-B28A-DBA584288632"}}',
    "tabOrder.v2": ["home", "feed", "reels", "downloads", "search"],
    "contentFlags": 3,
    "resetsFlagsOnLaunch": False,
    "autoplayVideos": False,
    "startMuted": False,
    "reelsFilter": b'{"onlyVideos":false,"includedTags":["kadse"],"excludedTags":["hund"]}',
    "recentSearches": "kadse\nfogel",
    "votes": b'{"items":{"42":1},"comments":{},"tags":{}}',
    "syncOffset": 17,
}, open(sys.argv[1], "wb"))
EOF

cp $root/Pr0gramm/Resources/Assets.xcassets/AppIcon.appiconset/icon.png "$container/Documents/Downloads/42.png"
print -r -- '[{"item":{"id":42,"promoted":7,"userId":3,"up":10,"down":2,"created":1700000000,"image":"2024/a.png","thumb":"2024/a.jpg","fullsize":"","preview":null,"width":640,"height":640,"audio":false,"source":null,"flags":1,"user":"cha0s","mark":2,"variants":null},"fileName":"42.png","date":721000000}]' \
    > "$container/Documents/Downloads/index.json"
print "seeded $container"
