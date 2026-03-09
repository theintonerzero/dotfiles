#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$HOME/.config"
mkdir -p "$HOME/.config/ghostty"

ln -sf "$DOTFILES_DIR/home/.zshrc" "$HOME/.zshrc"
ln -sf "$DOTFILES_DIR/home/.zprofile" "$HOME/.zprofile"
ln -sf "$DOTFILES_DIR/home/.gitconfig" "$HOME/.gitconfig"
ln -sf "$DOTFILES_DIR/home/.gitignore_global" "$HOME/.gitignore_global"

ln -sf "$DOTFILES_DIR/config/starship.toml" "$HOME/.config/starship.toml"
ln -sf "$DOTFILES_DIR/config/ghostty/config" "$HOME/.config/ghostty/config"
