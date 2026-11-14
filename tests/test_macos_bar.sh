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
