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
    echo >>"$HOME/.zprofile"
    echo "eval \"\$($BREW_PREFIX/bin/brew shellenv)\"" >>"$HOME/.zprofile"
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

# Node
if ! fnm list | grep -q "lts"; then
    echo "Installing Node LTS..."
    eval "$(fnm env --shell bash)"
    fnm install --lts
    fnm default lts-latest
else
    echo "Node LTS already installed, skipping..."
fi

# Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "Oh My Zsh already installed, skipping..."
fi

# Ensure .config exists as a real directory before stowing
if [ -L "$HOME/.config" ]; then
    echo "Removing bad .config symlink..."
    rm "$HOME/.config"
fi
mkdir -p "$HOME/.config"

# Stow helper
cd "$(dirname "$0")"

stow_package() {
    local pkg=$1
    local target=$2

    if [ -L "$target" ]; then
        echo "$pkg already stowed, restowing..."
        stow --restow "$pkg"
    else
        echo "Stowing $pkg..."
        stow "$pkg"
    fi
}

# zsh
if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
    mv "$HOME/.zshrc" "$HOME/.zshrc.bak"
fi
stow_package zsh "$HOME/.zshrc"

# git
if [ -f "$HOME/.gitconfig" ] && [ ! -L "$HOME/.gitconfig" ]; then
    mv "$HOME/.gitconfig" "$HOME/.gitconfig.bak"
fi
stow_package git "$HOME/.gitconfig"

# starship
stow_package starship "$HOME/.config/starship/starship.toml"

# ghostty
stow_package ghostty "$HOME/.config/ghostty/config"

# tmux
if [ -f "$HOME/.tmux.conf" ] && [ ! -L "$HOME/.tmux.conf" ]; then
    mv "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak"
fi
stow_package tmux "$HOME/.tmux.conf"

# Install tmux plugins
echo "Installing tmux plugins..."
tmux new-session -d -s setup 2>/dev/null || true
$(brew --prefix)/opt/tpm/share/tpm/bin/install_plugins
tmux kill-session -t setup 2>/dev/null || true

# Neovim
echo "Setting up Neovim..."

if [ -L "$HOME/.config/nvim" ]; then
    echo "Neovim already stowed, restowing..."
    stow --restow nvim
else
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

    echo "Stowing nvim..."
    stow nvim

    echo "Installing AstroNvim plugins (this may take a moment)..."
    nvim --headless -c 'quitall'
fi

echo "Neovim setup complete."
