#!/usr/bin/env bash
set -e

# Unstow helper
cd "$(dirname "$0")"

unstow_package() {
    local pkg=$1
    local target=$2

    if [ -L "$target" ]; then
        echo "Unstowing $pkg..."
        stow -D "$pkg"
    else
        echo "$pkg not stowed, skipping..."
    fi
}

# Unstow dotfiles
echo "Unstowing dotfiles..."
unstow_package zsh "$HOME/.zshrc"
unstow_package git "$HOME/.gitconfig"
unstow_package starship "$HOME/.config/starship/starship.toml"
unstow_package tmux "$HOME/.tmux.conf"
unstow_package ghostty "$HOME/.config/ghostty/config"

# Neovim
echo "Removing Neovim config..."

if [ -L "$HOME/.config/nvim" ]; then
    echo "Unstowing nvim..."
    stow -D nvim
else
    echo "nvim not stowed, skipping..."
fi

for dir in \
    "$HOME/.local/share/nvim" \
    "$HOME/.local/state/nvim" \
    "$HOME/.cache/nvim"; do
    if [ -d "$dir" ]; then
        echo "Removing $dir..."
        rm -rf "$dir"
    fi
done

echo "Neovim config removed."

# Oh My Zsh
if [ -d "$HOME/.oh-my-zsh" ]; then
    echo "Uninstalling Oh My Zsh..."
    ZSH="$HOME/.oh-my-zsh" sh "$HOME/.oh-my-zsh/tools/uninstall.sh" --unattended
else
    echo "Oh My Zsh not found, skipping..."
fi

# Homebrew
if [ -d /opt/homebrew ] || [ -d /usr/local/Cellar ]; then
    echo "Uninstalling Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
    sudo rm -rf /opt/homebrew 2>/dev/null || true
    sudo rm -rf /usr/local/Cellar /usr/local/Homebrew 2>/dev/null || true
    sed -i '' '/eval.*brew shellenv/d' ~/.zprofile
else
    echo "Homebrew not found, skipping..."
fi
