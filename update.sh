#!/usr/bin/env bash
# update.sh: pulls the dotfiles, then updates everything they installed
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib.sh"

[[ $(os_id) == fedora ]] || die "v1.0.1 supports Fedora only"
pull_dotfiles
load_steps fedora

keep_sudo
system_update
apps_update
link_home
shell_update
toolchains_update
neovim_update
vscodium_update
claude_update
godot_update
gnome_update
gaming_update
say "done"
todo_print
