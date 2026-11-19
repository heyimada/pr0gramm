#!/bin/zsh
# Walks every screen of the installed app on an iPhone Duo simulator and checks after each step
# that the app is still running and showing what the step expects; folds the device on reel 3,
# on the third feed and on a post past the first and checks each stays on its page; then saves
# a search as a feed and removes it again.
# Prints one "ok" or "FAIL" line per check and exits non-zero if any failed.
#
#   scripts/verify/smoke.sh <agent-device command>
#
# The agent-device command is the one T3 Code's device_open returns for the Duo. The run starts
# from the unfolded pose and ends folded open again. It saves and removes one feed, nothing else.
set -u
ad=$1
root=${0:A:h:h:h}
failures=0

running() { $ad appstate 2>&1 | grep -q 'runningForeground'; }
shows() { $ad snapshot -i 2>&1 | grep -qE "$1"; }
check() {
    local name=$1 pattern=$2
    if running && shows "$pattern"; then print "ok    $name"; else print "FAIL  $name"; failures=$((failures + 1)); fi
}
check_absent() {
    local name=$1 pattern=$2
    if running && ! shows "$pattern"; then print "ok    $name"; else print "FAIL  $name"; failures=$((failures + 1)); fi
}
tap() { $ad press "$1" > /dev/null 2>&1; sleep ${2:-2}; }
ref() { $ad snapshot -i 2>&1 | grep -m1 -E "$1" | grep -oE '@e[0-9]+(~s[0-9]+)?'; }
# The first label matching $1 whose element sits on screen. Lazy stacks keep neighbouring pages
# in the tree, and hidden tabs keep theirs, so the first match alone can be off screen.
first() {
    local line r rect x y i
    for i in {1..5}; do
        for line in ${(f)"$($ad snapshot -i 2>&1 | grep -E "$1" | grep -v '"pr0gramm"')"}; do
            r=$(print -r -- $line | grep -oE '@e[0-9]+(~s[0-9]+)?' | head -1)
            rect=$($ad get attrs $r --json 2>/dev/null | tr -d ' \n')
            x=$(print -r -- $rect | grep -oE '"x":-?[0-9.]+' | head -1 | cut -d: -f2)
            y=$(print -r -- $rect | grep -oE '"y":-?[0-9.]+' | head -1 | cut -d: -f2)
            if [[ -n $x && -n $y ]] && (( x >= 0 && x < 951 && y >= 0 && y < 669 )); then
                print -r -- $line | grep -oE "$1"
                return
            fi
        done
        sleep 2
    done
}

$ad fold open > /dev/null 2>&1
$ad open de.azula.pr0gramm --relaunch > /dev/null 2>&1
sleep 10
check "opens on the feed" 'Post [0-9]+ von'
check "downloads and profil tabs" 'button "Downloads"|"Downloads"'
check_absent "no start tab" 'role=button label="Start"|\[button\] "Start"'
tap "$(ref '\[button\] "Post [0-9]+ von')" 5
check "post opens" '"Teilen"'
$ad back > /dev/null 2>&1; sleep 2

tap 'role=button label="Reels"' 6
check "reels" 'Profil von'
tap "$(ref '\[button\] "[0-9]+"')" 4
check "reels comment sheet" '"Kommentare"'
tag=$(ref '\[button\] "[a-z]')
tap "$tag" 4
check "tag opens inside the sheet" '"Suche"'
$ad back > /dev/null 2>&1; sleep 2
tap 'role=button label="Fertig"' 2
tap 'role=button label="Reels-Filter"' 3
check "reels filter sheet" '"Nur Videos"'
tap 'role=button label="Fertig"' 2

tap 'role=button label="Feed"' 2
tap 'role=button label="Konto"' 3
check "account button opens profil" '"Profil" \[selected\]'
check "profil lists the settings" '"Einstellungen"'
tap "$(ref '"Feeds, ')" 3
check "settings feeds" '"Feed hinzufügen"'
$ad back > /dev/null 2>&1; sleep 2
tap "$(ref '"Navigation"')" 3
check "settings navigation" '"In der Leiste"'
$ad back > /dev/null 2>&1; sleep 2
tap "$(ref '"Einstellungen"')" 3
check "settings" '\[navigation-bar\] "Einstellungen"'
$ad back > /dev/null 2>&1; sleep 2
tap 'role=button label="Anmelden"' 4
check "login sheet" '"Captcha-Bild, tippen für ein neues"'
tap 'role=button label="Abbrechen"' 2

fold_keeps() {
    local name=$1 pattern=$2
    local before=$(first "$pattern")
    $ad fold closed > /dev/null 2>&1; sleep 4
    local after=$(first "$pattern")
    $ad fold open > /dev/null 2>&1; sleep 4
    local back=$(first "$pattern")
    if running && [[ -n $before && $before == $after && $before == $back ]]; then
        print "ok    fold keeps $name ($before)"
    else
        print "FAIL  fold keeps $name ($before / $after / $back)"; failures=$((failures + 1))
        $ad screenshot "$root/build/smoke-fail-${name// /-}.png" > /dev/null 2>&1
    fi
}

tap 'role=button label="Reels"' 4
$ad swipe 400 550 400 150 > /dev/null 2>&1; sleep 2
$ad swipe 400 550 400 150 > /dev/null 2>&1; sleep 3
fold_keeps "reel 3" 'Profil von [^"]+'

tap 'role=button label="Feed"' 3
sleep 2
tap "$(ref '"Feed: ')" 2
check "feed menu lists the presets" '"Best of"'
tap 'label="Zufall"' 5
check "zufall loads" '"Feed: Zufall"'
for attempt in {1..3}; do
    $ad swipe 150 300 750 300 > /dev/null 2>&1; sleep 3
    shows '"Feed: müll"' && break
done
check "swipes back from zufall" '"Feed: müll"'
for attempt in {1..3}; do
    $ad swipe 750 300 150 300 > /dev/null 2>&1; sleep 3
    shows '"Feed: Zufall"' && break
done
check "zufall stays as the last page" '"Feed: Zufall"'
tap "$(ref '"Feed: ')" 2
tap 'label="müll"' 4
fold_keeps "the third feed" '"Feed: müll"'

# Feed pages beside the shown one are in the tree too, so tap the visible grid by position.
tap 'role=button label="Feed"' 3
$ad press 300 250 > /dev/null 2>&1; sleep 5
$ad swipe 700 300 150 300 > /dev/null 2>&1; sleep 4
fold_keeps "a post past the first" '\[navigation-bar\] "[^"]+"'
$ad back > /dev/null 2>&1

sleep 2
for attempt in {1..3}; do
    tap 'role=button label="Suchen"' 3
    shows '\[search\]' && break
done
tap "$(ref '\[search\]')" 1
$ad type "smoketest" > /dev/null 2>&1
$ad type $'\n' > /dev/null 2>&1; sleep 5
check "search results" '"Als Feed speichern"'
tap 'role=button label="Als Feed speichern"' 3
check "feed editor" '"Neuer Feed"'
tap 'role=button label="Sichern"' 3
check "saved search shows as saved" '"Gespeicherten Feed entfernen"'
tap 'role=button label="Gespeicherten Feed entfernen"' 2
check "removed again" '"Als Feed speichern"'
$ad keyboard dismiss > /dev/null 2>&1
tap 'role=button label="Text löschen"' 1
tap 'role=button label="Schließen"' 2

print "$failures failed"
exit $(( failures > 0 ))
