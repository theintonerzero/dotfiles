#!/usr/bin/env bash
set -e

# Homebrew
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Determine arch
    if [[ "$(uname -m)" == "arm64" ]]; then
        BREW_PREFIX="/opt/homebrew"
    else
        BREW_PREFIX="/usr/local"
    fi

    # Add brew to PATH
    echo >> "$HOME/.zprofile"
    echo "eval \"\$($BREW_PREFIX/bin/brew shellenv)\"" >> "$HOME/.zprofile"
    eval "$($BREW_PREFIX/bin/brew shellenv)"
else
    echo "Homebrew already installed, skipping..."
fi

# Brewfile
BREWFILE_PATH="$(dirname "$0")/Brewfile"

if [ -f "$BREWFILE_PATH" ]; then
    echo "Installing packages from Brewfile..."
    brew bundle --file="$BREWFILE_PATH"
else
    echo "No Brewfile found at $BREWFILE_PATH, skipping..."
fi

# Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "Oh My Zsh already installed, skipping..."
fi

# AstroNvim
echo "Setting up Neovim..."

# Back up generated dirs from any previous install
for dir in \
    "$HOME/.local/share/nvim" \
    "$HOME/.local/state/nvim" \
    "$HOME/.cache/nvim"; do
    if [ -d "$dir" ] && [ ! -L "$dir" ]; then
        echo "Backing up $dir to $dir.bak"
        rm -rf "$dir.bak"        
        mv "$dir" "$dir.bak"
    fi
done

# Back up existing config only if it's a real directory
if [ -d "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
    echo "Backing up ~/.config/nvim to ~/.config/nvim.bak"
    mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak"
fi

# Symlink config via stow
echo "Stowing nvim..."
cd "$(dirname "$0")"
stow nvim

# Bootstrap plugins headlessly so nvim is ready on first open
echo "Installing AstroNvim plugins (this may take a moment)..."
nvim --headless -c 'quitall'

echo "Neovim setup complete."