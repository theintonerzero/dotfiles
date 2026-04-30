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