#!/usr/bin/env bash
# update.sh: pulls the dotfiles, then updates everything they installed
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib.sh"
need_bash "$@"

os=$(os_id)
[[ -f $DOTFILES/$os/steps.sh ]] || die "these dotfiles support Fedora, macOS and Ubuntu Server"
pull_dotfiles "$@"
load_steps "$os"

os_update
say "done"
todo_print
