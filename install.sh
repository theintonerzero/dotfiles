#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run ./install.sh as your normal user, not root."
  echo "This installer uses sudo internally when needed."
  exit 1
fi

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname)"

echo "Dotfiles directory: $DOTFILES_DIR"

if [[ "${OS}" == "Linux" && -f "$DOTFILES_DIR/linux/setup.sh" ]]; then
  echo ""
  echo "Running Fedora package setup..."
  bash "$DOTFILES_DIR/linux/setup.sh"
fi

echo ""
echo "Bootstrapping packages..."
"$DOTFILES_DIR/scripts/bootstrap.sh"

echo ""
echo "Creating symlinks..."
"$DOTFILES_DIR/scripts/symlink.sh"

echo ""
echo "Applying OS specific configuration..."

case "${OS}" in
  Darwin)
    if [[ -f "$DOTFILES_DIR/macos/defaults.sh" ]]; then
      echo "Applying macOS defaults..."
      bash "$DOTFILES_DIR/macos/defaults.sh"
    fi
    ;;
esac

echo ""
echo "Dotfiles installation complete."
echo "Restart your terminal or run:"
echo "  source ~/.zprofile"
echo "  source ~/.zshrc"
