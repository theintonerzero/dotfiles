#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERROR_COUNT=0
WARNING_COUNT=0

ok() {
  echo "[ok] $1"
}

warn() {
  echo "[warn] $1"
  WARNING_COUNT=$((WARNING_COUNT + 1))
}

fail() {
  echo "[fail] $1"
  ERROR_COUNT=$((ERROR_COUNT + 1))
}

check_repo_file() {
  local path="$1"

  if [[ -e "${DOTFILES_DIR}/${path}" ]]; then
    ok "Repo file exists: ${path}"
  else
    fail "Missing repo file: ${path}"
  fi
}

check_command() {
  local cmd="$1"

  if command -v "${cmd}" >/dev/null 2>&1; then
    ok "Command available: ${cmd}"
  else
    warn "Command missing: ${cmd}"
  fi
}

check_linux_login_shell() {
  local target_user="${SUDO_USER:-${USER}}"
  local expected_shell
  local current_shell

  if [[ "$(uname -s)" != "Linux" ]]; then
    return
  fi

  if ! command -v zsh >/dev/null 2>&1; then
    warn "Cannot verify login shell: zsh is unavailable."
    return
  fi

  if ! command -v getent >/dev/null 2>&1; then
    warn "Cannot verify login shell: getent is unavailable."
    return
  fi

  expected_shell="$(command -v zsh)"
  current_shell="$(getent passwd "${target_user}" | cut -d: -f7)"

  if [[ "${current_shell}" == "${expected_shell}" ]]; then
    ok "Login shell is zsh for ${target_user}"
  else
    warn "Login shell for ${target_user} is ${current_shell} (expected ${expected_shell})"
  fi
}

check_target_link() {
  local source="$1"
  local target="$2"

  if [[ -L "${target}" ]]; then
    local link_target
    link_target="$(readlink "${target}")"
    if [[ "${link_target}" == "${source}" ]]; then
      ok "Symlink is correct: ${target}"
    else
      warn "Symlink points elsewhere: ${target} -> ${link_target}"
    fi
    return
  fi

  if [[ -e "${target}" ]]; then
    warn "Target exists but is not a symlink: ${target}"
  else
    warn "Target is missing: ${target}"
  fi
}

check_oh_my_zsh() {
  local zsh_dir="${ZSH:-${HOME}/.oh-my-zsh}"
  local zsh_custom_dir="${ZSH_CUSTOM:-${zsh_dir}/custom}"
  local plugins=(
    zsh-autocomplete
    zsh-autosuggestions
    zsh-history-substring-search
    zsh-syntax-highlighting
  )
  local plugin

  if [[ -d "${zsh_dir}" ]]; then
    ok "Oh My Zsh directory exists: ${zsh_dir}"
  else
    warn "Oh My Zsh not found: ${zsh_dir}"
    return
  fi

  for plugin in "${plugins[@]}"; do
    if [[ -d "${zsh_custom_dir}/plugins/${plugin}" ]]; then
      ok "Oh My Zsh plugin exists: ${plugin}"
    else
      warn "Oh My Zsh plugin missing: ${plugin}"
    fi
  done
}

check_starship_prompt() {
  local starship_file="${DOTFILES_DIR}/config/starship.toml"
  if grep -Fq "\$status" "${starship_file}"; then
    ok "Starship format includes \$status"
  else
    fail "Starship format is missing \$status in ${starship_file}"
  fi
}

echo "Dotfiles doctor"
echo "Repo: ${DOTFILES_DIR}"
echo "OS: $(uname -s)"
echo

check_repo_file "install.sh"
check_repo_file "scripts/bootstrap.sh"
check_repo_file "scripts/symlink.sh"
check_repo_file "scripts/doctor.sh"
check_repo_file "scripts/update.sh"
check_repo_file "scripts/backups.sh"
check_repo_file "home/.zshrc"
check_repo_file "home/.zshenv"
check_repo_file "home/.zprofile"
check_repo_file "home/.gitconfig"
check_repo_file "home/.ssh/config"
check_repo_file "config/starship.toml"
check_repo_file "config/ghostty/config"
check_repo_file "macos/defaults.sh"
check_repo_file "linux/setup.sh"

echo

check_command git
check_command curl
check_command zsh
check_command tmux
check_command fzf
check_command starship
check_command zoxide
check_command atuin

case "$(uname -s)" in
  Darwin)
    check_command brew
    ;;
  Linux)
    if [[ -f /etc/fedora-release ]]; then
      check_command dnf
    else
      warn "Linux distro is not Fedora; bootstrap is Fedora-only."
    fi
    ;;
esac

check_linux_login_shell

echo

check_target_link "${DOTFILES_DIR}/home/.zshrc" "${HOME}/.zshrc"
check_target_link "${DOTFILES_DIR}/home/.zshenv" "${HOME}/.zshenv"
check_target_link "${DOTFILES_DIR}/home/.zprofile" "${HOME}/.zprofile"
check_target_link "${DOTFILES_DIR}/home/.gitconfig" "${HOME}/.gitconfig"
check_target_link "${DOTFILES_DIR}/home/.gitignore_global" "${HOME}/.gitignore_global"
check_target_link "${DOTFILES_DIR}/home/.tmux.conf" "${HOME}/.tmux.conf"
check_target_link "${DOTFILES_DIR}/home/.ssh/config" "${HOME}/.ssh/config"
check_target_link "${DOTFILES_DIR}/config/starship.toml" "${HOME}/.config/starship.toml"
check_target_link "${DOTFILES_DIR}/config/ghostty/config" "${HOME}/.config/ghostty/config"

echo

check_oh_my_zsh
check_starship_prompt

echo
echo "Summary: ${ERROR_COUNT} failure(s), ${WARNING_COUNT} warning(s)"

if ((ERROR_COUNT > 0)); then
  exit 1
fi

exit 0
