# shared/shell.sh: zsh as the login shell, fzf-tab, atuin's history import and btop's colours
# shellcheck shell=bash

shell_install() {
  local zsh
  zsh=$(command -v zsh)
  if [[ $(getent passwd "$USER" | cut -d: -f7) != "$zsh" ]]; then
    say "making zsh your login shell"
    as_root usermod -s "$zsh" "$USER"
    todo "log out and back in, so new terminals start zsh"
  fi
  fzf_tab
  atuin_import
  btop_colours
}

shell_update() {
  fzf_tab update
}

# fzf_tab: fzf-tab's newest commit, cloned once and pulled after that
fzf_tab() {
  local dir=${XDG_DATA_HOME:-$HOME/.local/share}/zsh/fzf-tab
  if [[ -d $dir/.git ]]; then
    [[ ${1:-} == update ]] || return 0
    git -C "$dir" pull -q --ff-only || warn "couldn't update fzf-tab"
  else
    say "installing fzf-tab"
    git clone -q --depth 1 https://github.com/Aloxaf/fzf-tab "$dir" || warn "couldn't install fzf-tab"
  fi
}

# atuin_import: your existing shell history goes into atuin, once
atuin_import() {
  local marker=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/atuin-imported
  [[ -e $marker ]] && return 0
  have atuin || return 0
  say "importing your shell history into atuin"
  atuin import auto >/dev/null 2>&1 || warn "atuin couldn't import your history"
  mkdir -p "$(dirname "$marker")"
  touch "$marker"
}

# btop_colours: btop in the terminal's colours; a file btop rewrites, so it's written once, not linked
btop_colours() {
  local conf=${XDG_CONFIG_HOME:-$HOME/.config}/btop/btop.conf
  [[ -e $conf ]] && return 0
  mkdir -p "$(dirname "$conf")"
  printf '%s\n' 'color_theme = "TTY"' 'theme_background = False' >"$conf"
}
