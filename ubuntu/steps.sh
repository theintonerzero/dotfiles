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
  with_neovim neovim_install neovim_parsers
}

os_update() {
  not_root
  keep_sudo
  system_update
  tools_update
  link_home
  shell_update
  with_neovim neovim_update neovim_parsers
}

os_uninstall() {
  not_root
  say "removing the links"
  unlink_home
  neovim_uninstall
}

# with_neovim <step...>: neovim's steps, on a machine that has neovim. one where it didn't install, as when
# github couldn't be asked for its release, is told so at the end, and the next run does them
with_neovim() {
  local step
  if ! have "${NEOVIM_CMD:-nvim}"; then
    todo "Neovim isn't installed yet, so its plugins and tools wait; run dot install again"
    return 0
  fi
  for step; do "$step"; done
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
  - zsh as your login shell, fzf-tab in ~/.local/share/zsh, and ghostty's terminal description in /etc/terminfo
  - app data: Neovim's plugins and tools in ~/.local/share/nvim, atuin's history
NOTES
}
