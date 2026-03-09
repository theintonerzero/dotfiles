#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run scripts/symlink.sh as your normal user, not root."
  exit 1
fi

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

link_file() {
  local source="$1"
  local target="$2"
  local backup_target

  mkdir -p "$(dirname "${target}")"

  if [[ -L "${target}" ]]; then
    local existing_link
    existing_link="$(readlink "${target}")"

    if [[ "${existing_link}" == "${source}" ]]; then
      echo "Already linked: ${target}"
      return
    fi
  fi

  if [[ -e "${target}" || -L "${target}" ]]; then
    backup_target="${target}.backup.${TIMESTAMP}"
    mv "${target}" "${backup_target}"
    echo "Backed up ${target} to ${backup_target}"
  fi

  ln -s "${source}" "${target}"
  echo "Linked ${target} -> ${source}"
}

link_file "${DOTFILES_DIR}/home/.zshrc" "${HOME}/.zshrc"
link_file "${DOTFILES_DIR}/home/.zshenv" "${HOME}/.zshenv"
link_file "${DOTFILES_DIR}/home/.zprofile" "${HOME}/.zprofile"
link_file "${DOTFILES_DIR}/home/.gitconfig" "${HOME}/.gitconfig"
link_file "${DOTFILES_DIR}/home/.gitignore_global" "${HOME}/.gitignore_global"
link_file "${DOTFILES_DIR}/home/.tmux.conf" "${HOME}/.tmux.conf"
link_file "${DOTFILES_DIR}/home/.ssh/config" "${HOME}/.ssh/config"

link_file "${DOTFILES_DIR}/config/starship.toml" "${HOME}/.config/starship.toml"
link_file "${DOTFILES_DIR}/config/ghostty/config" "${HOME}/.config/ghostty/config"

chmod 700 "${HOME}/.ssh"
