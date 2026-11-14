# tests/test_macos_desktop.sh: macos's settings from defaults.txt, the dock's apps and the power settings
# shellcheck shell=bash
# shellcheck disable=SC2016 # a stub's body is expanded when the stub runs
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
load macos
stub_defaults
stub killall

ok "bool" defaults_same bool 1 true
ok "bool false" defaults_same bool 0 false
no "bool differs" defaults_same bool 0 true
ok "int stored as float" defaults_same int 2.0 2
ok "float" defaults_same float 0.6875 0.6875
no "number differs" defaults_same int 64 48
no "not a number" defaults_same int "" 0
ok "string" defaults_same string Nlsv Nlsv
no "string differs" defaults_same string icnv Nlsv

# want: defaults.txt as the lines the defaults stub answers from, each key holding what the list asks for
want() {
  list "$REPO/macos/defaults.txt" | sed 's/^-currentHost //' | awk -v h="$HOME" '$3 != "delete" {
    v = $4; for (i = 5; i <= NF; i++) v = v " " $i
    sub(/^~/, h, v); if ($3 == "bool") v = (v == "true" ? 1 : 0)
    print $1, $2, v }'
}
ok "the list has settings" test "$(want | wc -l)" -gt 40

# everything as the list has it: nothing written, nothing restarted, nothing left for you
want >"$T/have"
(defaults_apply && [[ ${#TODOS[@]} == 0 ]])
not_called "defaults write"
not_called killall

# one setting off: that one written, and finder restarted once
want | grep -v ' ShowPathbar ' >"$T/have"
: >"$T/calls"
(defaults_apply >/dev/null)
called "defaults write com.apple.finder ShowPathbar -bool true"
eq "one write" 1 "$(calls | grep -c 'defaults write')"
eq "finder restarted once" 1 "$(calls | grep -c 'killall Finder')"
not_called "killall Dock"

# a fresh mac: everything written, each app restarted once, and logging out left for you, said once
: >"$T/have"
: >"$T/calls"
(defaults_apply >/dev/null && [[ ${TODOS[*]} == *"log out and back in"* && ${#TODOS[@]} == 1 ]])
called "defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1"
called "defaults write com.apple.screencapture location -string $HOME/Pictures/Screenshots"
called "defaults write NSGlobalDomain com.apple.mouse.scaling -float 0.6875"
called "defaults write com.apple.dock wvous-br-corner -int 1"
eq "every setting written" "$(want | grep -c .)" "$(calls | grep -c 'defaults.* write ')"
eq "dock restarted once" 1 "$(calls | grep -c 'killall Dock')"
eq "the menu bar restarted once" 1 "$(calls | grep -c 'killall SystemUIServer')"

# a key the list says to unset
echo "NSGlobalDomain AppleAccentColor delete" >"$T/list"
echo "NSGlobalDomain AppleAccentColor 2" >"$T/have"
: >"$T/calls"
(defaults_apply "$T/list" >/dev/null)
called "defaults delete NSGlobalDomain AppleAccentColor"
: >"$T/have"
: >"$T/calls"
(defaults_apply "$T/list")
not_called "defaults delete"

# the dock: an app that isn't installed is skipped, and the rest keep the list's order
mkdir -p "$APPS/Firefox.app" "$APPS/Ghostty.app"
: >"$T/calls"
: >"$T/dock"
(dock_apply >/dev/null)
line=$(calls | grep 'persistent-apps -array')
[[ $line == *"file://$APPS/Firefox.app/"*"file://$APPS/Ghostty.app/"* ]] || fail "the dock's apps, in order: $line"
[[ $line != *Vesktop* && $line != *Godot* ]] || fail "an app that isn't installed is in the dock: $line"
called "killall Dock"
# already so, and the dock spelling an app's name its own way: left alone
printf '"_CFURLString" = "file://%s/";\n' "$APPS/firefox.app" "$APPS/Ghostty.app" >"$T/dock"
: >"$T/calls"
(dock_apply)
not_called "defaults write"
not_called killall
eq "an app by name" "file://$APPS/Firefox.app/" "$(dock_url Firefox)"
eq "spaces in a path" "file:///Applications/Unity%20Hub.app/" "$(dock_url "/Applications/Unity Hub.app")"

# power: only what differs is set, on the charger
stub pmset '[[ $2 == cap ]] && { echo " highpowermode"; exit 0; }
printf "Battery Power:\n powermode 0\n displaysleep 2\nAC Power:\n powermode 0\n displaysleep 0\n"'
: >"$T/calls"
(power_apply >/dev/null)
called "sudo pmset -c powermode 2"
not_called "displaysleep"
# a mac with no high power mode isn't asked for it
stub pmset '[[ $2 == cap ]] && exit 0
printf "Battery Power:\n displaysleep 2\nAC Power:\n displaysleep 10\n"'
: >"$T/calls"
(power_apply >/dev/null)
not_called powermode
called "sudo pmset -c displaysleep 0"

# the screenshots folder, and ~/Library shown
mkdir -p "$HOME/Library"
/usr/bin/chflags hidden "$HOME/Library"
stub chflags
: >"$T/calls"
(desktop_folders >/dev/null)
ok "screenshots folder" test -d "$HOME/Pictures/Screenshots"
called "chflags nohidden $HOME/Library"
/usr/bin/chflags nohidden "$HOME/Library"
: >"$T/calls"
(desktop_folders)
not_called chflags
