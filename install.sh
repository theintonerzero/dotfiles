#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Dotfiles directory: $DOTFILES_DIR"

echo ""
echo "Bootstrapping packages..."
"$DOTFILES_DIR/scripts/bootstrap.sh"

echo ""
echo "Creating symlinks..."
"$DOTFILES_DIR/scripts/symlink.sh"

echo ""
echo "Applying OS specific configuration..."

case "$(uname)" in
  Darwin)
    if [[ -f "$DOTFILES_DIR/macos/defaults.sh" ]]; then
      echo "Applying macOS defaults..."
      bash "$DOTFILES_DIR/macos/defaults.sh"
    fi
    ;;
  Linux)
    if [[ -f "$DOTFILES_DIR/linux/setup.sh" ]]; then
      echo "Running Linux setup..."
      bash "$DOTFILES_DIR/linux/setup.sh"
    fi
    ;;
esac

echo ""
echo "Dotfiles installation complete."
echo "Restart your terminal or run:"
echo "  source ~/.zprofile"
echo "  source ~/.zshrc"