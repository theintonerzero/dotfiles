# tests/test_ubuntu.sh: ubuntu server: what it links, that it won't run as root, apt's packages, and each
# tool from apt or from its own release
# shellcheck shell=bash
# shellcheck disable=SC2016 # a stub's body is expanded when the stub runs
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
fresh_home() {
  rm -rf "$HOME"
  mkdir -p "$HOME"
}

# a server links the shell, git, tmux, neovim, the prompt and the small tools' config, and dot
(load ubuntu && link_home) >/dev/null
for p in .zshenv .config/zsh/.zshrc .config/git/config .config/tmux/tmux.conf .config/sesh/sesh.toml \
  .config/nvim/init.lua .config/starship.toml .config/lazygit/config.yml .config/atuin/config.toml .local/bin/dot; do
  ok "ubuntu links $p" test -e "$HOME/$p"
done
# and nothing a desktop or a development machine has
for p in .claude .config/ghostty .config/mise .local/bin/godot-nvim .local/bin/unity-project \
  .local/bin/blender-lab-mcp .config/gtk-4.0 .config/VSCodium Library; do
  no "ubuntu links no $p" test -e "$HOME/$p"
done
(load ubuntu && unlink_home) >/dev/null
no "unlinked" test -e "$HOME/.config/zsh/.zshrc"
no "nothing left linked into the repo" bash -c "find '$HOME' -type l -lname '$REPO/*' | grep -q ."

# the list names only packages there are
(
  load ubuntu
  while read -r pkg; do ok "home.txt's $pkg is a package" test -d "$REPO/home/$pkg"; done < <(list "$REPO/ubuntu/home.txt")
)
# fedora and macos still link every shared package
fresh_home
(load fedora && link_home) >/dev/null
ok "fedora still links claude's settings" test -e "$HOME/.claude/CLAUDE.md"
ok "fedora still links mise" test -e "$HOME/.config/mise/config.toml"

# install set up your own home, so it won't run as root, and stops before it does anything
out=$( (load ubuntu && not_root 0) 2>&1) && fail "as root: install stops"
[[ $out == *"not as root"* ]] || fail "as root: says why: $out"
eq "as root: nothing run" "" "$(calls)"
ok "as yourself: carries on" bash -c "source '$REPO/tests/helpers.sh'; load ubuntu; not_root 1000"

# apt: only what's missing is asked for, in one call, with no recommended extras
(
  load ubuntu
  stub dpkg-query '[[ ${*: -1} == zsh ]] && printf installed; exit 0'
  apt_packages >/dev/null
  eq "one install" 1 "$(calls | grep -c 'apt-get install')"
  called "sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends"
  line=$(calls | grep 'apt-get install')
  while read -r pkg; do
    if [[ $pkg == zsh ]]; then
      [[ " $line " != *" zsh "* ]] || fail "zsh is there already, so it isn't asked for"
    else
      [[ " $line " == *" $pkg "* ]] || fail "$pkg is asked for"
    fi
  done < <(list "$REPO/ubuntu/packages.txt")
)
(
  load ubuntu
  stub dpkg-query 'printf installed'
  apt_packages
  not_called "apt-get install"
)
(
  load ubuntu
  while read -r pkg; do [[ $pkg =~ ^[a-z0-9][a-z0-9.+-]+$ ]] || fail "packages.txt: $pkg isn't a package name"; done < <(list "$REPO/ubuntu/packages.txt")
  ok "a compiler, for neovim's parsers" grep -qx gcc <(list "$REPO/ubuntu/packages.txt")
)
# the package lists are fetched when there are none or they're a day old, and always for an update
(
  load ubuntu
  APT_LISTS=$T/lists
  mkdir -p "$APT_LISTS"
  apt_refresh >/dev/null
  called "sudo apt-get update"
  touch "$APT_LISTS/archive_dists_noble_InRelease"
  : >"$T/calls"
  apt_refresh
  not_called "apt-get update"
  touch -t 202001010000 "$APT_LISTS/archive_dists_noble_InRelease"
  apt_refresh >/dev/null
  called "sudo apt-get update"
  touch "$APT_LISTS/archive_dists_noble_InRelease"
  : >"$T/calls"
  apt_refresh force >/dev/null
  called "sudo apt-get update"
)
# an upgrade that needs a restart says so, and restarts nothing
(
  load ubuntu
  REBOOT_FLAG=$T/reboot-required
  apt_upgrade >/dev/null
  called "apt-get upgrade -y"
  [[ ${#TODOS[@]} == 0 ]] || fail "no restart needed: no todo"
  touch "$REBOOT_FLAG"
  apt_upgrade >/dev/null
  [[ ${TODOS[*]} == *"restart the computer"* ]] || fail "a restart is needed: a todo"
  not_called "reboot"
)
# debian's names for bat and fd, under the names everything else uses
(
  load ubuntu
  fresh_home
  stub batcat
  stub fdfind
  PATH=$T/bin:/usr/bin:/bin
  debian_names
  eq "bat" "$T/bin/batcat" "$(readlink "$HOME/.local/bin/bat")"
  eq "fd" "$T/bin/fdfind" "$(readlink "$HOME/.local/bin/fd")"
  eq "again: nothing said" "" "$(debian_names)"
  rm -f "$T/bin/batcat" "$T/bin/fdfind" "$HOME/.local/bin/bat" "$HOME/.local/bin/fd"
  debian_names
  no "no batcat: no bat link" test -L "$HOME/.local/bin/bat"
)
# ghostty's terminal description, where the system doesn't know it
(
  load ubuntu
  stub infocmp 'exit 1'
  stub tic
  terminfo_install >/dev/null
  called "tic -x -o $HOME/.terminfo $REPO/ubuntu/xterm-ghostty.terminfo"
  stub infocmp 'exit 0'
  : >"$T/calls"
  terminfo_install
  not_called "tic"
)
ok "the terminfo source describes xterm-ghostty" grep -q '^xterm-ghostty|' "$REPO/ubuntu/xterm-ghostty.terminfo"
