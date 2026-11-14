# tests/test_macos_bar.sh: the bar on macos: sketchybar from its author's tap, its config and plugins, and
# the step that runs it in place of apple's menu bar
# shellcheck shell=bash
# shellcheck disable=SC2016 # a stub's body is expanded when the stub runs
# shellcheck disable=SC2030,SC2031 # each case runs in a subshell of its own, on purpose
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

# --- the tap: added once, and only the one formula in it trusted ---

# a homebrew that has neither the tap nor the trust
(
  load macos
  stub brew 'case "$*" in "tap") ;; "trust --json v1") echo "{\"taps\":[],\"formulae\":[]}" ;; esac; exit 0'
  system_taps >/dev/null
  called "brew tap FelixKratz/formulae"
  called "brew trust --formula felixkratz/formulae/sketchybar"
  not_called "brew trust --tap"
  no "the tap as a whole is never trusted" grep -qxi 'brew trust felixkratz/formulae' "$T/calls"
  [[ ${#TODOS[@]} == 0 ]] || fail "tapped and trusted: no todo"
)
# one that has both: nothing to do, nothing said
(
  load macos
  stub brew 'case "$*" in "tap") echo felixkratz/formulae ;; "trust --json v1") echo "{\"taps\":[],\"formulae\":[\"felixkratz/formulae/sketchybar\"]}" ;; esac; exit 0'
  eq "again: nothing said" "" "$(system_taps)"
  no "again: not tapped twice" grep -q '^brew tap .' "$T/calls"
  not_called "brew trust --formula"
)
# a tap that can't be reached: said at the end, and install goes on
(
  load macos
  stub brew 'case "$*" in "tap") ;; "trust --json v1") echo "{}" ;; tap\ *) exit 1 ;; esac; exit 0'
  system_taps >/dev/null 2>&1 || fail "no tap: install goes on"
  [[ ${TODOS[*]} == *"FelixKratz/formulae"* ]] || fail "no tap: a todo names it"
  not_called "brew trust --formula"
)
(
  load macos
  ok "sketchybar is one of the formulae" grep -qx sketchybar <(list "$REPO/macos/formulae.txt")
  for f in system_taps system_formulae system_casks system_appstore xcode_setup system_removals; do eval "$f() { echo $f; }"; done
  eq "the tap comes before the formulae" "system_taps system_formulae" "$(system_install | grep -E '^system_(taps|formulae)$' | paste -sd' ' -)"
)

# --- the bar's plugins: each is run by sketchybar with NAME, SENDER and INFO, and answers with one call ---

B=$REPO/macos/home/sketchybar/.config/sketchybar
SURFACE=0xff282727 ACCENT=0xff7a8382 ERR=0xffc4746e OK=0xff87a987 DIM=0xff8c8882
stub sketchybar
# plugin <name> [VAR=value...]: runs a plugin as sketchybar would, and prints the one call it made
plugin() {
  local name=$1
  shift
  : >"$T/calls"
  env CONFIG_DIR="$B" TMPDIR="$T/tmp" NAME="$name" "$@" "$B/plugins/$name.sh" >/dev/null
  grep '^sketchybar ' "$T/calls" || true
}
# has <label> <call> <words...>: the call has each of the words
has() {
  local label=$1 call=$2 word
  shift 2
  for word; do [[ " $call " == *" $word "* ]] || fail "$label: wanted [$word] in [$call]"; done
}
mkdir -p "$T/tmp"

# the battery: plain, red at a fifth or less, green on the charger, and gone on a mac with none
batt() { stub pmset "printf '%s\n' \"Now drawing from '$1'\" \" -InternalBattery-0 (id=1)	$2; 3:10 remaining present: true\""; }
batt 'Battery Power' '78%; discharging'
call=$(plugin battery)
has "battery" "$call" drawing=on label=78% "background.color=$SURFACE"
batt 'Battery Power' '12%; discharging'
has "battery low" "$(plugin battery)" label=12% "background.color=$ERR"
batt 'Battery Power' '20%; discharging'
has "battery at a fifth is low" "$(plugin battery)" "background.color=$ERR"
batt 'Battery Power' '21%; discharging'
has "battery above a fifth isn't" "$(plugin battery)" "background.color=$SURFACE"
batt 'AC Power' '64%; charging'
has "battery charging" "$(plugin battery)" label=64% "label.color=$OK" "background.color=$SURFACE"
batt 'AC Power' '12%; charging'
has "low but charging is good news" "$(plugin battery)" "label.color=$OK" "background.color=$SURFACE"
batt 'AC Power' '100%; charged'
call=$(plugin battery)
has "battery full on the charger" "$call" label=100% "background.color=$SURFACE"
[[ $call != *"label.color=$OK"* ]] || fail "a full battery isn't charging"
stub pmset "echo \"Now drawing from 'AC Power'\""
has "a mac with no battery" "$(plugin battery)" drawing=off

# sound: only when it's muted
call=$(plugin volume SENDER=volume_change INFO=0)
has "muted" "$call" drawing=on label=muted "background.color=$ERR"
has "not muted" "$(plugin volume SENDER=volume_change INFO=45)" drawing=off
stub osascript 'echo 0'
has "muted, as bar starts" "$(plugin volume SENDER=forced)" drawing=on label=muted
stub osascript 'echo 30'
has "not muted, as bar starts" "$(plugin volume SENDER=forced)" drawing=off

# the network: only when there's none
stub route 'exit 1'
has "offline" "$(plugin network)" drawing=on label=offline "background.color=$ERR"
stub route 'exit 0'
has "online" "$(plugin network)" drawing=off

# spotify: only while it plays; what it names is shown as it is, never run
playing() { jq -n --arg s "$1" --arg a "$2" --arg n "$3" '{ "Player State": $s, Artist: $a, Name: $n }'; }
stub pgrep
call=$(plugin spotify SENDER=spotify_change INFO="$(playing Playing Bonobo Kerala)")
has "playing" "$call" drawing=on
[[ $call == *"label=Bonobo · Kerala"* ]] || fail "playing: artist and track: $call"
has "paused" "$(plugin spotify SENDER=spotify_change INFO="$(playing Paused Bonobo Kerala)")" drawing=off
has "stopped" "$(plugin spotify SENDER=spotify_change INFO="$(playing Stopped '' '')")" drawing=off
# shellcheck disable=SC2016 # the text is meant to reach the plugin unexpanded
nasty='a"b $(touch p1) `touch p2`'
call=$(cd "$T" && plugin spotify SENDER=spotify_change INFO="$(playing Playing X "$nasty")")
[[ $call == *"label=X · $nasty "* ]] || fail "an odd name is shown as it is: $call"
no "and nothing in it is run" test -e "$T/p1"
no "by backticks either" test -e "$T/p2"
call=$(plugin spotify SENDER=spotify_change INFO="$(playing Playing 'An Artist With A Long Name' 'And A Track Whose Name Goes On And On')")
[[ $call == *"label=An Artist With A Long Name · And A Trac… "* ]] || fail "a long name is cut to 40 letters: $call"
eq "no track name: the artist alone" "label=Bonobo" "$(plugin spotify SENDER=spotify_change INFO="$(playing Playing Bonobo '')" | grep -o 'label=[^ ]*')"
stub pgrep 'exit 1'
has "spotify quit: gone at the next look" "$(plugin spotify SENDER=routine)" drawing=off
stub pgrep
eq "spotify running, nothing new: left alone" "" "$(plugin spotify SENDER=routine)"
has "junk from spotify: nothing drawn" "$(plugin spotify SENDER=spotify_change INFO='not json')" drawing=off

# workspaces: the current one filled, one with windows a pill, an empty one bare
windows() { jq -n --argjson s "$1" --argjson a "$2" '{ space: $s, apps: $a }'; }
plugin space SID=2 SELECTED=false SENDER=space_windows_change INFO="$(windows 2 '{"Ghostty":1}')" >/dev/null
has "current" "$(plugin space SID=2 SELECTED=true SENDER=space_change)" "background.color=$ACCENT" background.drawing=on
has "has windows" "$(plugin space SID=2 SELECTED=false SENDER=space_change)" "background.color=$SURFACE" background.drawing=on
plugin space SID=3 SELECTED=false SENDER=space_windows_change INFO="$(windows 3 '{}')" >/dev/null
has "empty" "$(plugin space SID=3 SELECTED=false SENDER=space_change)" background.drawing=off "label.color=$DIM"
has "empty but current" "$(plugin space SID=3 SELECTED=true SENDER=space_change)" "background.color=$ACCENT" background.drawing=on
eq "another space's windows aren't this one's" "" "$(plugin space SID=3 SELECTED=false SENDER=space_windows_change INFO="$(windows 2 '{"Ghostty":1}')")"
has "still empty after it" "$(plugin space SID=3 SELECTED=false SENDER=space_change)" background.drawing=off
has "never heard about: taken to have windows" "$(plugin space SID=7 SELECTED=false SENDER=space_change)" background.drawing=on

# the front app, the date and the time
has "front app" "$(plugin front_app SENDER=front_app_switched INFO=Ghostty)" label=Ghostty
call=$(plugin clock)
[[ $call =~ --set\ clock\ label=[0-2][0-9]:[0-5][0-9]( |$) ]] || fail "the time, on a 24-hour clock: $call"
[[ $call =~ --set\ date\ label=[A-Z][a-z][a-z]\ [0-9]{1,2}\ [A-Z][a-z][a-z]( |$) ]] || fail "the date, as Sat 14 Nov: $call"

# the config itself: a bar with nothing behind it and nothing to click
: >"$T/calls"
env CONFIG_DIR="$B" "$B/sketchybarrc" >/dev/null
bar=$(grep '^sketchybar --bar ' "$T/calls")
has "the bar" "$bar" color=0x00000000 height=32 position=top
no "nothing to click" grep -rqE 'click_script|popup\.' "$B"
no "no menu-bar icon mirrored" grep -rqE -- '--add alias' "$B"
used=$(grep -oE 'plugins/[a-z_]+\.sh' "$B/sketchybarrc" | sort -u)
while read -r p; do
  ok "$p is there and can run" test -x "$B/$p"
done <<<"$used"
eq "every plugin is used" "$(cd "$B" && find plugins -name '*.sh' | sort | paste -sd' ' -)" "$(paste -sd' ' - <<<"$used")"
called "--add event spotify_change com.spotify.client.PlaybackStateChanged"

# only macos links it
(load macos && link_home) >/dev/null
ok "macos links the bar's config" test -e "$HOME/.config/sketchybar/sketchybarrc"
ok "and its plugins" test -x "$HOME/.config/sketchybar/plugins/battery.sh"
rm -rf "$HOME" && mkdir -p "$HOME"
(load fedora && link_home) >/dev/null
no "fedora doesn't" test -e "$HOME/.config/sketchybar"
