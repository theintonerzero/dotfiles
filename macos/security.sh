# macos/security.sh: touch id for sudo, the firewall, a reminder when filevault is off, and no analytics
# sent to apple
# shellcheck shell=bash

# the file apple keeps across macos updates for sudo's own additions, and homebrew's pam_reattach, which
# lets touch id reach you from inside tmux
SUDO_LOCAL=${SUDO_LOCAL:-/etc/pam.d/sudo_local}
PAM_REATTACH=${PAM_REATTACH:-/opt/homebrew/lib/pam/pam_reattach.so}
FIREWALL=${FIREWALL:-/usr/libexec/ApplicationFirewall/socketfilterfw}
ANALYTICS=${ANALYTICS:-/Library/Application Support/CrashReporter/DiagnosticMessagesHistory.plist}

security_install() {
  touch_id
  firewall_on
  filevault_check
  analytics_off
}

# sudo_local_want: sudo_local as it should be: touch id is enough for sudo, with pam_reattach before it
# only while its file is there, and optional, so sudo never fails for want of it
sudo_local_want() {
  echo "# sudo_local: touch id answers sudo, inside tmux too; written by the dotfiles (macos/security.sh)"
  if [[ -f $PAM_REATTACH ]]; then echo "auth       optional       $PAM_REATTACH ignore_ssh"; fi
  echo "auth       sufficient     pam_tid.so"
}

# touch_id: sudo_local written where it differs; your password still works where touch id can't
touch_id() {
  local want
  want=$(sudo_local_want)
  [[ -f $SUDO_LOCAL && $(<"$SUDO_LOCAL") == "$want" ]] && return 0
  say "letting touch id answer sudo"
  printf '%s\n' "$want" | as_root tee "$SUDO_LOCAL" >/dev/null || warn "couldn't write $SUDO_LOCAL"
}

# firewall_on: macos's firewall on, with signed apps still let in
firewall_on() {
  [[ -x $FIREWALL ]] || return 0
  [[ $("$FIREWALL" --getglobalstate 2>/dev/null) == *enabled* ]] && return 0
  say "turning on the firewall"
  as_root "$FIREWALL" --setglobalstate on >/dev/null || warn "couldn't turn on the firewall"
  as_root "$FIREWALL" --setallowsigned on >/dev/null || true
}

# filevault_check: turning disk encryption on asks for your password and gives you a recovery key, so
# it's yours to do
filevault_check() {
  [[ $(fdesetup status 2>/dev/null) == *"FileVault is On."* ]] && return 0
  todo "turn on FileVault (System Settings > Privacy & Security)"
}

# analytics_off: no analytics sent to apple or to app developers, where they're on
analytics_off() {
  local key
  [[ -f $ANALYTICS ]] || return 0
  for key in AutoSubmit ThirdPartyDataSubmit; do
    [[ $(defaults read "$ANALYTICS" "$key" 2>/dev/null) == 1 ]] || continue
    say "turning off macos's analytics ($key)"
    as_root defaults write "$ANALYTICS" "$key" -bool false || warn "couldn't turn off $key"
  done
}
