#!/usr/bin/env bash
# install.sh: sets this machine up from the dotfiles; safe to run again
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib.sh"
need_bash "$@"

os=$(os_id)
[[ -f $DOTFILES/$os/steps.sh ]] || die "these dotfiles support Fedora, macOS and Ubuntu Server"
load_steps "$os"

os_install
# what's left to sign in to, on an os that has any
if declare -F os_signins >/dev/null; then os_signins; fi
say "done"
todo_print
