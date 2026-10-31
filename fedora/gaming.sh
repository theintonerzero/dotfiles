# fedora/gaming.sh: steam's games by name, fsr4 on rdna4 cards, proton-ge as steam's default, and steam's
# performance monitor
# shellcheck shell=bash

STEAM=$HOME/.local/share/Steam

gaming_install() {
  gaming_names
  gaming_fsr4
  gaming_proton
  gaming_steam
}

gaming_update() {
  if proton_ge_installed; then
    say "updating Proton-GE"
    protonplus update all || warn "ProtonPlus couldn't update Proton-GE"
  else
    gaming_proton
    gaming_steam
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
  [[ -d "$STEAM/compatibilitytools.d/Proton-GE Latest" ]]
}

# proton-ge latest through protonplus, once steam has run
gaming_proton() {
  if [[ ! -f $STEAM/config/config.vdf ]]; then
    todo "open Steam once and sign in, then run dot update to add Proton-GE Latest"
    return 0
  fi
  proton_ge_installed && return 0
  say "installing Proton-GE Latest"
  protonplus install steam-system proton-ge latest || warn "ProtonPlus couldn't install Proton-GE Latest"
}

# gaming_steam: proton-ge latest as the default for every game, and the performance monitor in full
# detail at the top left, for each steam account here; steam writes its settings over these when it
# quits, so it has to be closed
gaming_steam() {
  local tool="InstallConfigStore/Software/Valve/Steam/CompatToolMapping/0"
  local system="UserLocalConfigStore/system" file
  local -a jobs=()
  [[ -f $STEAM/config/config.vdf ]] || return 0
  if proton_ge_installed; then
    jobs+=("$STEAM/config/config.vdf|$tool/name=Proton-GE Latest|$tool/config=|$tool/priority=75")
  fi
  for file in "$STEAM"/userdata/*/config/localconfig.vdf; do
    [[ -f $file ]] || continue
    jobs+=("$file|$system/InGameOverlayShowFPSCorner=1|$system/InGameOverlayShowFPSDetailLevel=4")
  done
  local job status
  local -a args
  for job in "${jobs[@]}"; do
    IFS='|' read -ra args <<<"$job"
    status=0
    python3 -I "$DOTFILES/fedora/steam-config.py" --check "${args[@]}" >/dev/null 2>&1 || status=$?
    ((status == 0)) && continue
    if ((status != 10)); then
      warn "couldn't read ${args[0]}"
      continue
    fi
    if pgrep -x steam >/dev/null; then
      todo "quit Steam, then run dot install again for Proton-GE as its default and its performance monitor"
      return 0
    fi
    python3 -I "$DOTFILES/fedora/steam-config.py" "${args[@]}" | while read -r line; do say "$line"; done ||
      warn "couldn't change ${args[0]}"
  done
}
