# tests/test_macos_apps.sh: touch id for sudo, the firewall, filevault's reminder, firefox's policies, the
# default browser, the environment of apps started from the dock, and lm studio
# shellcheck shell=bash
# shellcheck disable=SC2016 # a stub's body is expanded when the stub runs
# shellcheck disable=SC2030,SC2031 # the cases run in subshells, on purpose
# shellcheck disable=SC2034 # the steps under test read the variables set here
# shellcheck disable=SC2329 # gh_tag and gh_asset are replaced, so no test asks github anything
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
load macos

# touch id: sudo loads pam_reattach from a root-owned copy outside homebrew, never from homebrew's own
# folder, which you can write to and which goes when the formula does: macos's pam fails every sudo when
# a module it names is missing, optional or not. with no copy there, the file names pam_tid alone
PAM_REATTACH="$T/brew/pam_reattach.so" PAM_REATTACH_COPY="$T/pam/pam_reattach.so" SUDO_LOCAL="$T/sudo_local"
mkdir -p "$T/brew" "$T/pam"
echo module >"$PAM_REATTACH"
eq "no copy: tid alone" 1 "$(sudo_local_want | grep -c '^auth')"
no "no copy: no reattach line" grep -q reattach <<<"$(sudo_local_want)"
: >"$T/calls"
(touch_id >/dev/null)
called "sudo install -d -m 755 $T/pam"
called "sudo install -m 444 -o root -g wheel $PAM_REATTACH $PAM_REATTACH_COPY"
cp "$PAM_REATTACH" "$PAM_REATTACH_COPY"
eq "the copy first" "$PAM_REATTACH_COPY" "$(sudo_local_want | awk '/^auth/ { print $3; exit }')"
no "homebrew's own path is never named" grep -qF "$PAM_REATTACH " <<<"$(sudo_local_want)"
eq "tid last" pam_tid.so "$(sudo_local_want | awk '/^auth/ { m = $3 } END { print m }')"
sudo_local_want >"$SUDO_LOCAL"
: >"$T/calls"
(touch_id)
not_called "sudo"
# a newer module from homebrew is copied again
echo newer >"$PAM_REATTACH"
: >"$T/calls"
(touch_id >/dev/null)
called "sudo install -m 444 -o root -g wheel $PAM_REATTACH $PAM_REATTACH_COPY"
echo newer >"$PAM_REATTACH_COPY"
# a sudo_local that isn't the dotfiles' is kept beside the new one
echo "auth sufficient pam_mine.so" >"$SUDO_LOCAL"
: >"$T/calls"
(touch_id >/dev/null)
called "sudo cp -p $SUDO_LOCAL $SUDO_LOCAL.bak"
called "sudo tee $SUDO_LOCAL"
# the dotfiles' own older one is just replaced
{ echo "# sudo_local: written by the dotfiles (macos/security.sh)"; echo "auth sufficient pam_tid.so"; } >"$SUDO_LOCAL"
: >"$T/calls"
(touch_id >/dev/null)
not_called "sudo cp"
called "sudo tee $SUDO_LOCAL"

# the firewall
stub fw 'echo "Firewall is disabled. (State = 0)"'
FIREWALL="$T/bin/fw"
: >"$T/calls"
(firewall_on >/dev/null)
called "sudo $T/bin/fw --setglobalstate on"
called "sudo $T/bin/fw --setallowsigned on"
stub fw 'echo "Firewall is enabled. (State = 1)"'
: >"$T/calls"
(firewall_on)
not_called sudo

# filevault
stub fdesetup 'echo "FileVault is Off."'
(filevault_check && [[ ${TODOS[*]} == *FileVault* ]])
stub fdesetup 'echo "FileVault is On."'
(filevault_check && [[ ${#TODOS[@]} == 0 ]])

# analytics: only what's on is turned off
ANALYTICS="$T/analytics.plist"
touch "$ANALYTICS"
stub_defaults
echo "$ANALYTICS AutoSubmit 1" >"$T/have"
: >"$T/calls"
(analytics_off >/dev/null)
called "sudo defaults write $ANALYTICS AutoSubmit -bool false"
not_called ThirdPartyDataSubmit\ -bool
echo "$ANALYTICS AutoSubmit 0" >"$T/have"
: >"$T/calls"
(analytics_off)
not_called sudo

# firefox's policies: the file fedora uses, as firefox's settings domain takes it
ok "the policies firefox gets" jq -e '.EnterprisePoliciesEnabled == true and .HttpsOnlyMode == "enabled"
  and .DisableTelemetry == true and .NoDefaultBookmarks == true
  and .ExtensionSettings["uBlock0@raymondhill.net"].installation_mode == "normal_installed"
  and .Homepage.StartPage == "previous-session" and (has("policies") | not)' <<<"$(firefox_policies_want)" >/dev/null
ok "fedora reads the moved file" grep -q 'shared/firefox-policies.json' "$REPO/fedora/apps.sh"
no "fedora's old path is gone" grep -q 'fedora/firefox-policies.json' "$REPO/fedora/apps.sh"
mkdir -p "$APPS/Firefox.app"
FIREFOX_POLICIES="$T/firefox-domain"
stub defaults '[[ $1 == export ]] || exit 0
if [[ -f $T/firefox.plist ]]; then cat "$T/firefox.plist"; else printf "%s\n" "<plist version=\"1.0\"><dict/></plist>"; fi'
: >"$T/calls"
(firefox_policies >/dev/null && [[ ${TODOS[*]} == *"restart Firefox"* ]])
called "sudo defaults import $T/firefox-domain"
# once the domain holds them, as macos gives them back, nothing is set again
firefox_policies_want >"$T/want.json"
plutil -convert xml1 -o "$T/firefox.plist" "$T/want.json"
: >"$T/calls"
(firefox_policies && [[ ${#TODOS[@]} == 0 ]])
not_called "defaults import"

# the default browser; handlers <bundle id> is the https handler as `defaults read … LSHandlers` prints it
handlers() {
  printf '(\n    {\n        LSHandlerPreferredVersions = {\n            LSHandlerRoleAll = "-";\n        };\n        LSHandlerRoleAll = "%s";\n        LSHandlerURLScheme = https;\n    }\n)\n' "$1" >"$T/handlers"
}
stub defaultbrowser
stub defaults 'cat "$T/handlers" 2>/dev/null || exit 1'
handlers com.apple.safari
: >"$T/calls"
(default_browser >/dev/null && [[ ${TODOS[*]} == *"default browser"* ]])
called "defaultbrowser firefox"
handlers org.mozilla.firefox
: >"$T/calls"
(default_browser && [[ ${#TODOS[@]} == 0 ]])
not_called "defaultbrowser firefox"
# a fresh mac has no handlers at all, and safari is its browser
rm "$T/handlers"
: >"$T/calls"
(default_browser >/dev/null)
called "defaultbrowser firefox"

# apps started from the dock get the shell's path, from a launch agent that's a real file
stub launchctl
: >"$T/calls"
(gui_env >/dev/null)
f="$HOME/Library/LaunchAgents/dev.dotfiles.environment.plist"
ok "a real file, not a link" test -f "$f" -a ! -L "$f"
ok "a valid plist" plutil -lint "$f" >/dev/null
ok "sets the path" grep -q 'launchctl setenv PATH' "$f"
ok "and unity's switches" grep -q UNITY_NO_UPDATE_CHECK "$f"
called "launchctl bootstrap gui/$UID $f"
: >"$T/calls"
(gui_env)
not_called "launchctl bootstrap"
(apps_uninstall >/dev/null 2>&1)
no "uninstall removes the agent" test -e "$f"

# artcraft launcher at the newest release already: nothing downloaded
gh_tag() { echo v0.19.2; }
mkdir -p "$APPS/ArtCraft Launcher.app/Contents"
plutil -create xml1 "$APPS/ArtCraft Launcher.app/Contents/Info.plist"
plutil -insert CFBundleShortVersionString -string 0.19.2 "$APPS/ArtCraft Launcher.app/Contents/Info.plist"
stub curl
stub hdiutil
: >"$T/calls"
(dmg_release storytold/craft-launcher 'x' "ArtCraft Launcher")
not_called curl
not_called hdiutil
# an older one: the newest release's dmg is fetched
gh_tag() { echo v0.20.0; }
gh_asset() { echo https://example.invalid/artcraft.dmg; }
stub_download dmg
stub hdiutil 'exit 1'
: >"$T/calls"
(dmg_release storytold/craft-launcher 'x' "ArtCraft Launcher" >/dev/null 2>&1) && fail "a dmg that won't open: a failure"
called "https://example.invalid/artcraft.dmg"
called "hdiutil attach"

# lm studio: its settings wait until it has run once
mkdir -p "$APPS/LM Studio.app"
(llm_install && [[ ${TODOS[*]} == *"open LM Studio once"* ]])
mkdir -p "$HOME/.lmstudio/bin"
printf '#!/bin/sh\n' >"$HOME/.lmstudio/bin/lms"
chmod +x "$HOME/.lmstudio/bin/lms"
echo '{}' >"$HOME/.lmstudio/settings.json"
stub pgrep 'exit 1'
(llm_install >/dev/null && [[ ${#TODOS[@]} == 0 ]])
ok "lm studio's settings merged" jq -e '.developerMode == true' "$HOME/.lmstudio/settings.json" >/dev/null

# podman: fedora's runs containers on its own kernel; on macos it needs a linux vm, made once
(
  stub podman '[[ "$*" == "machine list -q" ]] && exit 0; exit 0'
  podman_machine >/dev/null
  called "podman machine init"
)
(
  stub podman '[[ "$*" == "machine list -q" ]] && echo podman-machine-default; exit 0'
  : >"$T/calls"
  podman_machine
  not_called "podman machine init"
)
(
  stub podman '[[ "$*" == "machine list -q" ]] && exit 0; echo "no disk space" >&2; exit 1'
  : >"$T/calls"
  podman_machine >/dev/null 2>&1 || fail "a vm that can't be made doesn't stop install"
  [[ ${TODOS[*]} == *"podman machine init"* ]] || fail "a vm that can't be made: a todo"
)
(
  rm -f "$T/bin/podman"
  : >"$T/calls"
  PATH=$T/bin:/usr/bin:/bin podman_machine
  not_called "podman"
)
ok "podman is listed" grep -qx 'podman' <(list "$REPO/macos/formulae.txt")
ok "wget is listed" grep -qx 'wget' <(list "$REPO/macos/formulae.txt")
ok "install makes podman's vm" grep -qx '  podman_machine' "$REPO/macos/apps.sh"
