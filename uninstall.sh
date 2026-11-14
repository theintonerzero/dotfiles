#!/usr/bin/env bash
# uninstall.sh: removes the links and the files install made; packages and settings stay
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib.sh"
need_bash "$@"

os=$(os_id)
[[ -f $DOTFILES/$os/steps.sh ]] || die "these dotfiles support Fedora and macOS"
load_steps "$os"

os_uninstall
say "done"
os_uninstall_notes
