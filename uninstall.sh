#!/usr/bin/env bash
set -e

if [ -d /opt/homebrew ] || [ -d /usr/local/Cellar ]; then
    echo "Uninstalling Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
    
    # Delete left-over homebrew directories
    sudo rm -rf /opt/homebrew 2>/dev/null || true
    sudo rm -rf /usr/local/Cellar /usr/local/Homebrew 2>/dev/null || true
    
    # Remove shellenv line
    sed -i '' '/eval.*brew shellenv/d' ~/.zprofile
else
    echo "Homebrew not found, nothing to uninstall..."
fi