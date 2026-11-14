# ubuntu/steps.sh: the steps ubuntu server runs, in order; a server gets the shell, git, tmux and
# neovim, asks nothing and signs in to nothing
# shellcheck shell=bash

os_install() {
  not_root
  keep_sudo
  system_install
  tools_install
  link_home
  shell_install
  neovim_install
}

os_update() {
  keep_sudo
  system_update
  tools_update
  link_home
  shell_update
  neovim_update
}

os_uninstall() {
  say "removing the links"
  unlink_home
  neovim_uninstall
}

# not_root [uid]: install sets up the home of whoever runs it, so it stops for root before doing anything
not_root() {
  if [[ ${1:-$EUID} == 0 ]]; then die "run this as yourself, not as root: it sets up your own home, and asks for sudo when it needs it"; fi
}

# os_uninstall_notes: what uninstall leaves behind, said once it's done
os_uninstall_notes() {
  cat <<'NOTES'

These stay, so remove them yourself if you want them gone:
  - the packages apt installed
  - the tools that came from their own releases, in ~/.local/opt, and their links in ~/.local/bin
  - zsh as your login shell, fzf-tab in ~/.local/share/zsh, and ghostty's terminfo in ~/.terminfo
  - app data: Neovim's plugins and tools in ~/.local/share/nvim, atuin's history
NOTES
}
