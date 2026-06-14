# Dotfiles

My personal dotfiles. Supported on **macOS** and **Fedora Linux**.

The installer detects your OS and uses the right package manager:
- **macOS** : Homebrew (`Brewfile`)
- **Fedora** : `dnf` + COPR + Flatpak

## One-liner for macOS and Linux

```bash
curl -s https://dl.intonerzero.com/github/dotfiles/install.sh | bash
```

## Manual install

```bash
git clone <repo> ~/dotfiles
cd ~/dotfiles
./install.sh
```

Restart your shell (or `exec zsh`) afterwards. To remove the symlinks, run `./uninstall.sh`.
