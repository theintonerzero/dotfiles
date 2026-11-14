# macos/security.sh: touch id for sudo, the firewall, a reminder when filevault is off, and no analytics
# sent to apple
# shellcheck shell=bash

# the file apple keeps across macos updates for sudo's own additions; homebrew's pam_reattach, which lets
# touch id reach you from inside tmux; and the root-owned copy of it that sudo loads. sudo never loads
# homebrew's own: you can write to that folder, so anything running as you could swap in a module that
# sudo then runs as root, and macos's pam fails every sudo when a module it names is gone, as it would be
# once the formula or homebrew is removed
SUDO_LOCAL=${SUDO_LOCAL:-/etc/pam.d/sudo_local}
PAM_REATTACH=${PAM_REATTACH:-/opt/homebrew/lib/pam/pam_reattach.so}
PAM_REATTACH_COPY=${PAM_REATTACH_COPY:-/usr/local/lib/pam/pam_reattach.so}
FIREWALL=${FIREWALL:-/usr/libexec/ApplicationFirewall/socketfilterfw}
ANALYTICS=${ANALYTICS:-/Library/Application Support/CrashReporter/DiagnosticMessagesHistory.plist}

security_install() {
  touch_id
  firewall_on
  filevault_check
  analytics_off
}

# sudo_local_want: sudo_local as it should be: touch id is enough for sudo, with the copy of pam_reattach
# before it only while that file is there
sudo_local_want() {
  echo "# sudo_local: touch id answers sudo, inside tmux too; written by the dotfiles (macos/security.sh)"
  if [[ -f $PAM_REATTACH_COPY ]]; then echo "auth       optional       $PAM_REATTACH_COPY ignore_ssh"; fi
  echo "auth       sufficient     pam_tid.so"
}

# pam_reattach_copy: homebrew's pam_reattach copied where only root can change it, again when homebrew
# has a newer one
pam_reattach_copy() {
  [[ -f $PAM_REATTACH ]] || return 0
  cmp -s "$PAM_REATTACH" "$PAM_REATTACH_COPY" && return 0
  say "copying pam_reattach where sudo can trust it"
  if ! { as_root install -d -m 755 "${PAM_REATTACH_COPY%/*}" &&
    as_root install -m 444 -o root -g wheel "$PAM_REATTACH" "$PAM_REATTACH_COPY"; }; then
    warn "couldn't copy pam_reattach, so touch id won't reach you inside tmux"
  fi
}

# touch_id: sudo_local written where it differs, and one that isn't the dotfiles' kept as sudo_local.bak;
# your password still works where touch id can't
touch_id() {
  local want
  pam_reattach_copy
  want=$(sudo_local_want)
  [[ -f $SUDO_LOCAL && $(<"$SUDO_LOCAL") == "$want" ]] && return 0
  say "letting touch id answer sudo"
  if [[ -f $SUDO_LOCAL ]] && ! grep -q 'written by the dotfiles' "$SUDO_LOCAL"; then
    as_root cp -p "$SUDO_LOCAL" "$SUDO_LOCAL.bak" || true
  fi
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
