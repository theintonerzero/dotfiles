#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${SUDO_USER:-${USER}}"

run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
    return
  fi

  echo "This command needs root privileges, but sudo is unavailable."
  exit 1
}

install_first_available_package() {
  local label="$1"
  shift

  local pkg
  for pkg in "$@"; do
    if run_as_root dnf install -y "${pkg}"; then
      echo "Installed ${label}: ${pkg}"
      return 0
    fi
  done

  return 1
}

install_required_package() {
  local pkg="$1"

  if run_as_root dnf install -y "${pkg}"; then
    echo "Installed required package: ${pkg}"
    return 0
  fi

  echo "Missing required package in configured repos: ${pkg}"
  return 1
}

install_starship() {
  local starship_repo="atim/starship"

  if command -v starship >/dev/null 2>&1; then
    echo "Starship already installed."
    return 0
  fi

  echo "Enabling COPR repository for Starship: ${starship_repo}"
  if run_as_root dnf copr enable -y "${starship_repo}"; then
    if run_as_root dnf install -y starship; then
      echo "Installed Starship from COPR (${starship_repo})."
      return 0
    fi
  else
    echo "Could not enable COPR ${starship_repo}."
  fi

  if run_as_root dnf install -y starship; then
    echo "Installed Starship from Fedora repositories."
    return 0
  fi

  if command -v curl >/dev/null 2>&1; then
    if curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "${HOME}/.local/bin"; then
      echo "Installed Starship via upstream installer."
      return 0
    fi
  fi

  if command -v cargo >/dev/null 2>&1; then
    if cargo install --locked starship; then
      echo "Installed Starship via cargo."
      return 0
    fi
  fi

  echo "Warning: Starship installation failed."
  return 1
}

install_required_packages() {
  local required_packages=(
    git
    curl
    zsh
    tmux
    fzf
    neovim
    ripgrep
    nodejs
    python3
    rustup
    gh
    tree
    dnf-plugins-core
    fontconfig
  )
  local missing_packages=()
  local pkg

  for pkg in "${required_packages[@]}"; do
    if ! install_required_package "${pkg}"; then
      missing_packages+=("${pkg}")
    fi
  done

  if install_required_package fd-find || install_required_package fd; then
    :
  else
    missing_packages+=("fd-find/fd")
  fi

  if ! install_starship; then
    missing_packages+=("starship")
  fi

  if (( ${#missing_packages[@]} > 0 )); then
    echo "Warning: some required tools were not installed: ${missing_packages[*]}"
  fi
}

install_optional_packages() {
  local optional_packages=(
    zoxide
    atuin
    lazygit
    bat
    eza
    watchman
    jetbrains-mono-fonts
    firefox
    vlc
  )
  local pkg

  for pkg in "${optional_packages[@]}"; do
    if run_as_root dnf install -y "${pkg}"; then
      echo "Installed optional package: ${pkg}"
    else
      echo "Skipping unavailable optional package: ${pkg}"
    fi
  done
}

install_nerd_fonts() {
  local installed_any=0

  if install_first_available_package \
    "JetBrains Mono Nerd Font package" \
    jetbrains-mono-nerd-fonts \
    nerd-fonts-jetbrains-mono \
    nerd-fonts-jetbrainsmono; then
    installed_any=1
  else
    echo "JetBrains Mono Nerd Font package not found in current Fedora repos."
  fi

  if install_first_available_package \
    "Nerd symbols font package" \
    symbols-only-nerd-fonts \
    nerd-fonts-symbols-only \
    nerd-fonts-symbols \
    nerd-fonts; then
    installed_any=1
  else
    echo "Nerd symbols package not found in current Fedora repos."
  fi

  if (( installed_any == 0 )); then
    echo "Warning: no Nerd Fonts package was installed."
    echo "Starship powerline glyphs may render incorrectly until a Nerd Font is installed."
    return
  fi

  if run_as_root fc-cache -f; then
    echo "Refreshed font cache."
  fi
}

install_ghostty_from_copr() {
  local repo="scottames/ghostty"

  echo "Enabling COPR repository: ${repo}"
  if ! run_as_root dnf copr enable -y "${repo}"; then
    echo "Skipping Ghostty install: could not enable COPR ${repo}"
    return
  fi

  echo "Installing Ghostty..."
  if run_as_root dnf install -y ghostty; then
    echo "Installed Ghostty from COPR."
  else
    echo "Skipping Ghostty install: package installation failed."
  fi
}

ensure_default_shell_is_zsh() {
  local zsh_path
  local current_shell

  if ! command -v zsh >/dev/null 2>&1; then
    echo "zsh is not installed; cannot set default shell."
    return
  fi

  zsh_path="$(command -v zsh)"
  current_shell="$(getent passwd "${TARGET_USER}" | cut -d: -f7)"

  if [[ "${current_shell}" == "${zsh_path}" ]]; then
    echo "Default login shell is already zsh (${zsh_path})."
    return
  fi

  if run_as_root usermod --shell "${zsh_path}" "${TARGET_USER}"; then
    echo "Set default login shell for ${TARGET_USER} to ${zsh_path}."
    echo "Log out and back in for the shell change to take effect."
  else
    echo "Could not set default shell automatically."
    echo "Run this manually:"
    echo "  chsh -s \"${zsh_path}\" \"${TARGET_USER}\""
  fi
}

if [[ "$(uname)" != "Linux" ]]; then
  echo "linux/setup.sh can only run on Linux."
  exit 1
fi

if [[ ! -f /etc/fedora-release ]]; then
  echo "Linux setup currently supports Fedora only."
  exit 1
fi

if ! command -v dnf >/dev/null 2>&1; then
  echo "dnf is required on Fedora but is not available."
  exit 1
fi

echo "Applying Fedora-specific setup..."

echo "Installing required Fedora packages..."
install_required_packages

echo "Installing optional Fedora packages..."
install_optional_packages

echo "Installing Nerd Fonts for Starship glyph support..."
install_nerd_fonts

install_ghostty_from_copr

ensure_default_shell_is_zsh

echo "Fedora setup complete."
