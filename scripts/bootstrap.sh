#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run scripts/bootstrap.sh as your normal user, not root."
  exit 1
fi

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZSH_DIR="${HOME}/.oh-my-zsh"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-${ZSH_DIR}/custom}"

bootstrap_macos() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not installed."
    exit 1
  fi

  brew bundle --file="${DOTFILES_DIR}/Brewfile"
}

bootstrap_linux() {
  if [[ ! -f /etc/fedora-release ]]; then
    echo "Linux bootstrap currently supports Fedora only."
    exit 1
  fi
}

ensure_oh_my_zsh() {
  if ! command -v git >/dev/null 2>&1; then
    echo "git is required to bootstrap Oh My Zsh and plugins."
    echo "Run linux/setup.sh first on Fedora."
    exit 1
  fi

  if [[ -d "${ZSH_DIR}/.git" ]]; then
    echo "Oh My Zsh is already installed."
    return
  fi

  if [[ -e "${ZSH_DIR}" ]]; then
    echo "Oh My Zsh path already exists and is not a git checkout: ${ZSH_DIR}"
    echo "Skipping automatic installation."
    return
  fi

  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "${ZSH_DIR}"
}

ensure_zsh_plugin() {
  local repo="$1"
  local name="$2"
  local plugin_dir="${ZSH_CUSTOM_DIR}/plugins/${name}"

  mkdir -p "${ZSH_CUSTOM_DIR}/plugins"

  if [[ -d "${plugin_dir}/.git" ]]; then
    echo "Zsh plugin already installed: ${name}"
    return
  fi

  if [[ -e "${plugin_dir}" ]]; then
    echo "Zsh plugin path already exists and is not a git checkout: ${plugin_dir}"
    echo "Skipping automatic installation for ${name}."
    return
  fi

  git clone --depth=1 "https://github.com/${repo}.git" "${plugin_dir}"
}

case "$(uname)" in
  Darwin)
    bootstrap_macos
    ;;
  Linux)
    bootstrap_linux
    ;;
  *)
    echo "Unsupported OS."
    exit 1
    ;;
esac

ensure_oh_my_zsh
ensure_zsh_plugin "marlonrichert/zsh-autocomplete" "zsh-autocomplete"
ensure_zsh_plugin "zsh-users/zsh-autosuggestions" "zsh-autosuggestions"
ensure_zsh_plugin "zsh-users/zsh-history-substring-search" "zsh-history-substring-search"
ensure_zsh_plugin "zsh-users/zsh-syntax-highlighting" "zsh-syntax-highlighting"
