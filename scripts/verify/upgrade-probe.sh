#!/bin/zsh
# Prints what the installed app shows for the seeded saved data: tab bar, Start's selected feed,
# the video switches, the Reels tag filter, the Downloads grid and recent searches.
# Usage: scripts/verify/upgrade-probe.sh <agent-device command> > output.txt
# Run once with the old build installed over seeded data, once after installing the new build
# over the same data, and diff the two outputs.
set -u
ad=$1

$ad open de.azula.pr0gramm --relaunch > /dev/null 2>&1
sleep 6
print "## tabs"
$ad snapshot -i 2>&1 | grep -E '\[button\] "(Start|Feed|Reels|Downloads|Suchen)"' | sed 's/^.*\[button\]/[button]/'
print "## start switcher"
$ad snapshot -i 2>&1 | grep -E '\[button\] "(beliebt|neu|müll|Katzen)"' | sed 's/^.*\[button\]/[button]/'

$ad press 'role=popupbutton label="Konto"' > /dev/null 2>&1
sleep 1
$ad press 'role=button label="Einstellungen"' > /dev/null 2>&1
sleep 2
$ad scroll down --until 'label="Stumm starten"' > /dev/null 2>&1
sleep 1
print "## video settings"
$ad snapshot -i 2>&1 | grep -E '"(Automatisch abspielen|Stumm starten)"' | sed 's/^.*\[switch\]/[switch]/'
$ad press 'role=button label="Fertig"' > /dev/null 2>&1
sleep 1

$ad press 'role=button label="Reels"' > /dev/null 2>&1
sleep 4
print "## reels filter"
$ad snapshot -i 2>&1 | grep -E '"(#kadse \+1|ohne #hund)"' | sed 's/^.*\] /] /'

$ad press 'role=button label="Downloads"' > /dev/null 2>&1
sleep 2
print "## downloads"
$ad snapshot -i 2>&1 | grep -E 'Post 42|Keine Downloads' | sed 's/^.*\] /] /'

$ad press 'role=button label="Suchen"' > /dev/null 2>&1
sleep 2
$ad keyboard dismiss > /dev/null 2>&1
print "## recent searches"
$ad snapshot -i 2>&1 | grep -E '\[button\] "(kadse|fogel)"' | sed 's/^.*\[button\]/[button]/'
