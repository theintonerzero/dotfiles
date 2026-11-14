# ubuntu/system.sh: apt's packages, bat and fd under the names everything else uses, and ghostty's
# terminal description
# shellcheck shell=bash

APT_LISTS=${APT_LISTS:-/var/lib/apt/lists}
REBOOT_FLAG=${REBOOT_FLAG:-/var/run/reboot-required}

system_install() {
  apt_refresh
  apt_packages
  debian_names
  terminfo_install
}

system_update() {
  apt_refresh force
  apt_upgrade
  debian_names
}

# apt_refresh [force]: apt's package lists, fetched when there are none or the newest is a day old, as on a
# fresh server, or always when forced
apt_refresh() {
  if [[ ${1:-} != force ]] &&
    find "$APT_LISTS" -maxdepth 1 -type f \( -name '*InRelease' -o -name '*_Packages*' \) -mtime -1 2>/dev/null | grep -q .; then
    return 0
  fi
  say "fetching apt's package lists"
  quiet as_root apt-get update || warn "apt couldn't fetch its package lists"
}

# apt_missing: the packages in packages.txt that aren't installed
apt_missing() {
  local pkg
  while read -r pkg; do
    [[ $(dpkg-query -W -f='${db:Status-Status}' "$pkg" 2>/dev/null) == installed ]] || echo "$pkg"
  done < <(list "$DOTFILES/ubuntu/packages.txt")
}

# apt_packages: what's missing, in one install, without the extras apt would recommend
apt_packages() {
  local -a missing
  mapfile -t missing < <(apt_missing)
  ((${#missing[@]})) || return 0
  say "installing ${#missing[@]} packages"
  as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
}

# apt_upgrade: every package at its newest, restarting services without asking; a restart of the
# computer is yours to do
apt_upgrade() {
  say "upgrading apt's packages"
  as_root env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get upgrade -y ||
    warn "apt couldn't upgrade the packages"
  if [[ -e $REBOOT_FLAG ]]; then todo "restart the computer: Ubuntu says an update needs it"; fi
}

# debian_names: debian installs bat as batcat and fd as fdfind, as other packages had those names first;
# the plain names are links in ~/.local/bin, unless something else already answers to them
debian_names() {
  local pair name deb found
  for pair in bat:batcat fd:fdfind; do
    name=${pair%%:*} deb=${pair##*:}
    have "$deb" || continue
    found=$(command -v "$name" 2>/dev/null) || found=""
    [[ -z $found || $found == "$HOME/.local/bin/$name" ]] || continue
    [[ $(readlink "$HOME/.local/bin/$name" 2>/dev/null) == "$(command -v "$deb")" ]] && continue
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$(command -v "$deb")" "$HOME/.local/bin/$name"
  done
}

# terminfo_install: ghostty's terminal description in ~/.terminfo, where the system has none, so tmux and
# neovim know the terminal you ssh in from
terminfo_install() {
  infocmp xterm-ghostty >/dev/null 2>&1 && return 0
  have tic || return 0
  say "adding ghostty's terminal description"
  tic -x -o "$HOME/.terminfo" "$DOTFILES/ubuntu/xterm-ghostty.terminfo" || warn "couldn't add ghostty's terminal description"
}
