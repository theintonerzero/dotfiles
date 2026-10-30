# fedora/gaming.sh: steam's games by name, fsr4 on rdna4 cards, and proton-ge
# shellcheck shell=bash

gaming_install() {
  gaming_names
  gaming_fsr4
  gaming_proton
}

gaming_update() {
  if proton_ge_installed; then
    say "updating Proton-GE"
    protonplus update all || warn "ProtonPlus couldn't update Proton-GE"
  else
    gaming_proton
  fi
}

gaming_uninstall() {
  local file
  systemctl --user disable --now steam-apps.path steam-apps.service >/dev/null 2>&1 || true
  for file in "${XDG_DATA_HOME:-$HOME/.local/share}"/applications/steam_app_*.desktop; do
    if [[ -f $file ]] && grep -q '^X-Dotfiles-Steam-App=' "$file"; then rm -f "$file"; fi
  done
  rm -f "$HOME/.config/environment.d/fsr4.conf"
}

# steam-apps now, at each login, and whenever steam's games change
gaming_names() {
  systemctl --user daemon-reload
  if ! systemctl --user is-enabled --quiet steam-apps.path; then
    say "naming steam's games for gnome"
    systemctl --user enable --now steam-apps.path steam-apps.service
  fi
  "$HOME/.local/bin/steam-apps" >/dev/null || warn "steam-apps couldn't name steam's games"
}

# fsr4 for proton-ge's games, when the card is rdna4 (navi 4x)
gaming_fsr4() {
  local file=$HOME/.config/environment.d/fsr4.conf
  grep -qE 'Navi 4[0-9]' <<<"$(lspci 2>/dev/null)" || return 0
  [[ -f $file ]] && return 0
  say "turning on FSR4 for your RDNA4 card"
  mkdir -p "$(dirname "$file")"
  printf '%s\n' "# fsr4 for proton-ge games, set by the dotfiles for this rdna4 card" "PROTON_FSR4_UPGRADE=1" >"$file"
  todo "log out and back in, so Steam's games get FSR4"
}

proton_ge_installed() {
  [[ -d "$HOME/.local/share/Steam/compatibilitytools.d/Proton-GE Latest" ]]
}

# proton-ge latest through protonplus, once steam has run
gaming_proton() {
  if [[ ! -f $HOME/.local/share/Steam/config/config.vdf ]]; then
    todo "open Steam once and sign in, then run dot update to add Proton-GE Latest"
    return 0
  fi
  proton_ge_installed && return 0
  say "installing Proton-GE Latest"
  if protonplus install steam-system proton-ge latest; then
    todo "make Proton-GE Latest Steam's default: Steam > Settings > Compatibility"
  else
    warn "ProtonPlus couldn't install Proton-GE Latest"
  fi
}
