# shared/neovim.sh: astronvim's plugins, then the language servers, formatters and debuggers mason installs
# shellcheck shell=bash

neovim_install() {
  say "installing neovim's plugins and language tools"
  nvim --headless "+Lazy! install" +qa
  nvim --headless "+MasonToolsInstallSync" +qa
  neovim_kotlin
  neovim_netcoredbg
}

neovim_update() {
  nvim --headless "+Lazy! sync" +qa || warn "Neovim's plugins didn't update"
  nvim --headless "+MasonToolsInstallSync" +qa || warn "Neovim's Mason tools didn't install"
  nvim --headless "+MasonToolsUpdateSync" +qa || warn "Neovim's Mason tools didn't update"
  neovim_kotlin
  neovim_netcoredbg
}

# neovim_parsers: treesitter's parsers, waited for, where a machine wants them there before neovim is first
# opened; without this they arrive as neovim starts, and a run with no screen is over before they have
neovim_parsers() {
  quiet nvim --headless "+luafile $DOTFILES/shared/neovim-parsers.lua" +qa ||
    warn "Neovim's treesitter parsers didn't all install; opening Neovim fetches the rest"
}

neovim_uninstall() {
  local link=$HOME/.local/bin/kotlin-lsp
  if [[ -L $link && $(readlink "$link") == */mason/bin/intellij-server ]]; then rm -f "$link"; fi
}

# neovim_netcoredbg: mason has only an intel netcoredbg for a mac, which an apple silicon one can't run, so
# the config asks for none there (lua/plugins/mason.lua); one an earlier install left is taken away.
# neovim says a command went fine whether it did or not, so what's checked is whether the folder went
neovim_netcoredbg() {
  local dir=${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/packages/netcoredbg
  [[ $(os_id) == macos && $(uname -m) == arm64 ]] || return 0
  [[ -d $dir ]] || return 0
  say "removing mason's intel netcoredbg, which this mac can't run"
  nvim --headless "+MasonUninstall netcoredbg" +qa || true
  [[ ! -d $dir ]] || warn "couldn't remove Mason's netcoredbg: run :MasonUninstall netcoredbg in Neovim"
}

# neovim_kotlin: claude's kotlin plugin runs kotlin-lsp, the name jetbrains' own package gives intellij-server
neovim_kotlin() {
  local server=${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/bin/intellij-server
  [[ -x $server ]] || return 0
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$server" "$HOME/.local/bin/kotlin-lsp"
}
