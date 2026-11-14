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
