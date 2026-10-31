#!/usr/bin/env bash
# uninstall.sh: removes the links and the files install made; packages and settings stay
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib.sh"

[[ $(os_id) == fedora ]] || die "v1.2.0 supports Fedora only"
load_steps fedora

say "removing the links"
unlink_home
gaming_uninstall
apps_uninstall
neovim_uninstall
godot_uninstall
say "done"
cat <<'EOF'

These stay, so remove them yourself if you want them gone:
  - the packages, Flatpaks and repos install added
  - GNOME's settings, extensions and dock
  - app data: Neovim's plugins, Claude Code's plugins and MCP servers, VSCodium's extensions
  - your git identity in ~/.config/git/local and your SSH key
EOF
