#!/usr/bin/env bash
set -e

# ----------------------------------------------------------------------------
# OS detection
# ----------------------------------------------------------------------------
detect_os() {
    case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)
        if [ -r /etc/os-release ] && grep -qiE '^ID=fedora' /etc/os-release; then
            echo "fedora"
        else
            echo "unsupported"
        fi
        ;;
    *) echo "unsupported" ;;
    esac
}

OS="$(detect_os)"
if [ "$OS" = "unsupported" ]; then
    echo "Unsupported OS. This installer supports macOS and Fedora Linux." >&2
    exit 1
fi
echo "Detected OS: $OS"

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

# ----------------------------------------------------------------------------
# macOS packages (Homebrew)
# ----------------------------------------------------------------------------
install_macos() {
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

    local brewfile="$DOTFILES_DIR/Brewfile"
    if [ -f "$brewfile" ]; then
        echo "Installing packages from Brewfile..."
        brew bundle --file="$brewfile"
    else
        echo "No Brewfile found at $brewfile, skipping..."
    fi
}

# ----------------------------------------------------------------------------
# Fedora packages (dnf + COPR + flatpak + installers)
# ----------------------------------------------------------------------------
install_fedora() {
    echo "Installing Fedora packages with dnf..."
    sudo dnf install -y \
        coreutils curl wget2-wget git git-lfs \
        zsh tmux fzf zoxide atuin \
        zsh-autosuggestions zsh-syntax-highlighting \
        stow \
        golang rustup \
        neovim gcc gcc-c++ make \
        ripgrep fd-find bat eza git-delta jq btop gh \
        ghostty firefox \
        dotnet-sdk-8.0 texlive-scheme-basic \
        zlib-devel bzip2 bzip2-devel readline-devel sqlite sqlite-devel \
        openssl-devel xz xz-devel libffi-devel tk-devel ncurses-devel

    install_fedora_jdk

    if ! command -v lazygit &>/dev/null; then
        echo "Enabling COPR atim/lazygit..."
        sudo dnf copr enable -y atim/lazygit
        sudo dnf install -y lazygit
    else
        echo "lazygit already installed, skipping..."
    fi

    if ! command -v cargo &>/dev/null; then
        echo "Setting up Rust toolchain..."
        if command -v rustup-init &>/dev/null; then
            rustup-init -y --no-modify-path
        elif command -v rustup &>/dev/null; then
            rustup default stable
        fi
    else
        echo "Rust toolchain already installed, skipping..."
    fi

    install_starship
    install_fnm
    install_pyenv

    install_flatpaks

    install_nerd_font

    local login_shell
    login_shell="$(getent passwd "$USER" | cut -d: -f7)"
    if [ "$login_shell" != "$(command -v zsh)" ]; then
        echo "Changing default shell to zsh..."
        if chsh -s "$(command -v zsh)"; then
            echo "Default shell changed to zsh."
        else
            echo "chsh failed; change your login shell manually: chsh -s \"\$(command -v zsh)\""
        fi
    else
        echo "Default shell is already zsh."
    fi
    echo "NOTE: terminals (incl. Ghostty) read the shell from \$SHELL first, which only"
    echo "      updates on a new login session. Log out and back in (or reboot) for"
    echo "      Ghostty to start zsh automatically."
}

install_fedora_jdk() {
    local candidates=(java-21-openjdk-devel java-17-openjdk-devel java-latest-openjdk-devel)
    for pkg in "${candidates[@]}"; do
        if dnf info "$pkg" >/dev/null 2>&1; then
            echo "Installing JDK: $pkg"
            sudo dnf install -y "$pkg"
            return
        fi
    done
    echo "No suitable OpenJDK -devel package found, skipping JDK."
}

install_starship() {
    if command -v starship &>/dev/null; then
        echo "starship already installed, skipping..."
        return
    fi
    echo "Installing starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
}

install_fnm() {
    if command -v fnm &>/dev/null; then
        echo "fnm already installed, skipping..."
        return
    fi
    echo "Installing fnm..."
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$HOME/.local/bin" --skip-shell
}

install_pyenv() {
    if [ -d "$HOME/.pyenv" ]; then
        echo "pyenv already installed, skipping..."
        return
    fi
    echo "Installing pyenv..."
    curl -fsSL https://pyenv.run | bash
}

install_flatpaks() {
    if ! command -v flatpak &>/dev/null; then
        echo "flatpak not found, skipping GUI apps."
        return
    fi
    echo "Configuring Flathub..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    sudo flatpak remote-modify --enable --no-filter flathub 2>/dev/null || true

    local apps=(
        com.spotify.Client
        com.jetbrains.RustRover
    )
    for app in "${apps[@]}"; do
        echo "Installing flatpak: $app"
        flatpak install -y --noninteractive flathub "$app" || echo "  (failed: $app — skipping)"
    done
}

install_nerd_font() {
    local font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
    if [ -d "$font_dir" ] && ls "$font_dir"/*.ttf >/dev/null 2>&1; then
        echo "JetBrains Mono Nerd Font already installed, skipping..."
        return
    fi
    echo "Installing JetBrains Mono Nerd Font..."
    mkdir -p "$font_dir"
    local tmp
    tmp="$(mktemp -d)"
    if curl -fsSL -o "$tmp/JetBrainsMono.tar.xz" \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz; then
        tar -xJf "$tmp/JetBrainsMono.tar.xz" -C "$font_dir"
        fc-cache -f "$font_dir" >/dev/null 2>&1 || fc-cache -f >/dev/null 2>&1 || true
    else
        echo "  (font download failed — skipping)"
    fi
    rm -rf "$tmp"
}

# ----------------------------------------------------------------------------
# Node (shared, via fnm)
# ----------------------------------------------------------------------------
install_node() {
    if ! command -v fnm &>/dev/null; then
        echo "fnm not found, skipping Node install."
        return
    fi
    eval "$(fnm env --shell bash)"
    if ! fnm list | grep -q "lts"; then
        echo "Installing Node LTS..."
        fnm install --lts
        fnm default lts-latest
    else
        echo "Node LTS already installed, skipping..."
    fi
}

# ----------------------------------------------------------------------------
# Package installation
# ----------------------------------------------------------------------------
case "$OS" in
macos) install_macos ;;
fedora) install_fedora ;;
esac

install_node

# ----------------------------------------------------------------------------
# Oh My Zsh
# ----------------------------------------------------------------------------
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "Oh My Zsh already installed, skipping..."
fi

# ----------------------------------------------------------------------------
# Stow
# ----------------------------------------------------------------------------
# Ensure .config exists as a real directory before stowing
if [ -L "$HOME/.config" ]; then
    echo "Removing bad .config symlink..."
    rm "$HOME/.config"
fi
mkdir -p "$HOME/.config"

cd "$DOTFILES_DIR"

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

# btop
stow_package btop "$HOME/.config/btop/btop.conf"

# ----------------------------------------------------------------------------
# tmux plugins (TPM) — standard cross-platform location
# ----------------------------------------------------------------------------
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
    echo "Installing TPM..."
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi
echo "Installing tmux plugins..."
tmux new-session -d -s setup 2>/dev/null || true
"$TPM_DIR/bin/install_plugins" || true
tmux kill-session -t setup 2>/dev/null || true

# ----------------------------------------------------------------------------
# Neovim
# ----------------------------------------------------------------------------
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
echo "Done. Restart your shell (or run: exec zsh) to load the new environment."
