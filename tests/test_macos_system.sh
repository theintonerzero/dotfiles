# tests/test_macos_system.sh: homebrew's formulae and casks, app store apps and xcode, and apple's apps
# removed
# shellcheck shell=bash
# shellcheck disable=SC2016 # a stub's body is expanded when the stub runs
# shellcheck disable=SC2030,SC2031 # each case runs in a subshell of its own, on purpose
# shellcheck disable=SC2034 # GARAGEBAND_FILES is read by the step under test
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

# only what homebrew hasn't installed is installed
(
  load macos
  list "$REPO/macos/formulae.txt" | grep -vx binwalk >"$T/installed"
  stub brew '[[ "$*" == "list --formula -1" ]] && cat "$T/installed"; exit 0'
  system_formulae >/dev/null
  called "brew install binwalk"
  eq "only the missing one" 1 "$(calls | grep -c '^brew install')"
)
# what the questions and the linking need comes first
(
  load macos
  stub brew '[[ "$*" == "list --formula -1" ]] && echo gh; exit 0'
  system_first >/dev/null
  called "brew install jq"
  called "brew install stow"
  not_called "brew install gh"
)

# one cask failing doesn't stop the rest, and is named at the end
(
  load macos
  stub brew '[[ "$*" == "install --cask vesktop" ]] && exit 1; exit 0'
  system_casks >/dev/null 2>&1
  called "brew install --cask ghostty"
  called "brew install --cask spotify"
  [[ ${TODOS[*]} == *vesktop* ]] || fail "a failed cask: a todo"
  eq "one todo" 1 "${#TODOS[@]}"
)

# not signed in to the app store: a todo, the run goes on, and nothing of xcode's is set up
(
  load macos
  stub mas '[[ $1 == install ]] && exit 1; exit 0'
  stub xcodebuild
  stub xcode-select
  system_appstore >/dev/null 2>&1
  xcode_setup
  called "mas install 497799835"
  [[ ${TODOS[*]} == *"sign in to the App Store"*Xcode* ]] || fail "no sign-in: a todo"
  not_called xcodebuild
  not_called "xcode-select -s"
)
# xcode already there, from the app store: not installed again
(
  load macos
  # mas lines its ids up on the right, so a shorter one has a space before it
  stub mas '[[ $1 == list ]] && printf "%s\n" "1631624924  Final Cut Pro   (12.4)" " 497799835  Xcode           (27.2)"; exit 0'
  system_appstore
  not_called "mas install"
)
# xcode there but never opened: selected, licence accepted, first launch run
(
  load macos
  mkdir -p "$APPS/Xcode.app"
  stub xcode-select '[[ $1 == -p ]] && echo /Library/Developer/CommandLineTools'
  stub xcodebuild 'exit 1'
  xcode_setup >/dev/null
  called "sudo xcode-select -s $APPS/Xcode.app/Contents/Developer"
  called "sudo xcodebuild -license accept"
  called "sudo xcodebuild -runFirstLaunch"
)
# xcode set up: left alone
(
  load macos
  mkdir -p "$APPS/Xcode.app"
  stub xcode-select '[[ $1 == -p ]] && echo "$APPS/Xcode.app/Contents/Developer"'
  stub xcodebuild
  xcode_setup
  not_called sudo
)
rm -rf "$APPS/Xcode.app"

# apple's apps in remove.txt that are there are removed, garageband's sound library with it
(
  load macos
  mkdir -p "$APPS/GarageBand.app" "$APPS/Pages.app" "$T/loops"
  GARAGEBAND_FILES=("$T/loops" "$T/absent")
  # a sudo that does remove an app, as the real one does
  stub sudo 'if [[ $1 == rm && $3 == *.app ]]; then rm -rf "$3"; fi'
  system_removals >/dev/null 2>&1
  called "sudo rm -rf $APPS/GarageBand.app"
  called "sudo rm -rf $APPS/Pages.app"
  called "sudo rm -rf $T/loops"
  not_called "$APPS/iMovie.app"
  not_called "$T/absent"
  [[ ${#TODOS[@]} == 0 ]] || fail "apps removed: no todo"
)
stub sudo
# an app macos won't let the terminal remove (sudo is a stub here, so it stays): a todo, and its sound
# library stays with it
(
  load macos
  mkdir -p "$APPS/GarageBand.app" "$T/loops"
  GARAGEBAND_FILES=("$T/loops")
  system_removals >/dev/null 2>&1
  called "sudo rm -rf $APPS/GarageBand.app"
  not_called "rm -rf $T/loops"
  [[ ${TODOS[*]} == *"remove GarageBand yourself"* ]] || fail "an app that stays: a todo"
)
rm -rf "$APPS"/*.app
# logic pro shares that library, so with it installed the library stays
(
  load macos
  mkdir -p "$APPS/GarageBand.app" "$APPS/Logic Pro.app" "$T/loops"
  GARAGEBAND_FILES=("$T/loops")
  system_removals >/dev/null 2>&1
  called "sudo rm -rf $APPS/GarageBand.app"
  not_called "rm -rf $T/loops"
)
rm -rf "$APPS"/*.app
# nothing to remove: nothing asked of sudo
(
  load macos
  GARAGEBAND_FILES=("$T/absent")
  system_removals
  not_called sudo
)

(
  load macos
  stub brew
  stub mas
  system_update >/dev/null
  called "brew update"
  called "brew upgrade"
  called "mas upgrade"
)
