# dotfiles

Personal dotfiles for macOS and Fedora Linux.

## Install

```bash
git clone https://github.com/theintonerzero/dotfiles.git
cd dotfiles
./install.sh
```

Run the installer as your normal user (not `sudo`).

## CI

GitHub Actions runs `bash -n`, `zsh -n`, `shellcheck`, and Brewfile validation.
