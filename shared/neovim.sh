# shared/neovim.sh: astronvim's plugins, then the language servers, formatters and debuggers mason installs
# shellcheck shell=bash

neovim_install() {
  say "installing neovim's plugins and language tools"
  nvim --headless "+Lazy! install" +qa
  nvim --headless "+MasonToolsInstallSync" +qa
  neovim_kotlin
}

neovim_update() {
  nvim --headless "+Lazy! sync" +qa || warn "Neovim's plugins didn't update"
  nvim --headless "+MasonToolsInstallSync" +qa || warn "Neovim's Mason tools didn't install"
  nvim --headless "+MasonToolsUpdateSync" +qa || warn "Neovim's Mason tools didn't update"
  neovim_kotlin
}

neovim_uninstall() {
  local link=$HOME/.local/bin/kotlin-lsp
  if [[ -L $link && $(readlink "$link") == */mason/bin/intellij-server ]]; then rm -f "$link"; fi
}

# neovim_kotlin: claude's kotlin plugin runs kotlin-lsp, the name jetbrains' own package gives intellij-server
neovim_kotlin() {
  local server=${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/bin/intellij-server
  [[ -x $server ]] || return 0
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$server" "$HOME/.local/bin/kotlin-lsp"
}
