#!/usr/bin/env bash
# install.sh: sets this machine up from the dotfiles; safe to run again
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib.sh"

[[ $(os_id) == fedora ]] || die "v1.2.0 supports Fedora only"
load_steps fedora

ask_questions
keep_sudo
set_hostname
system_install
apps_install
link_home
shell_install
git_install
toolchains_install
neovim_install
vscodium_install
godot_install
claude_install
gnome_install
gaming_install
todo "sign in to Claude (claude), Copilot (:Copilot auth in Neovim), Spotify and Vesktop"
say "done"
todo_print
