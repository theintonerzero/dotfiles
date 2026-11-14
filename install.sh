#!/usr/bin/env bash
# install.sh: sets this machine up from the dotfiles; safe to run again
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib.sh"
need_bash "$@"

os=$(os_id)
[[ -f $DOTFILES/$os/steps.sh ]] || die "these dotfiles support Fedora and macOS"
load_steps "$os"

os_install
todo "sign in to Claude (claude), Copilot (:Copilot auth in Neovim), Spotify and Vesktop"
say "done"
todo_print
