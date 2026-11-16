# shared/vscodium.sh: vscodium's extensions, from open vsx, and c#'s debugger on an apple silicon mac; its
# settings are linked
# shellcheck shell=bash

vscodium_install() {
  local have id
  have codium || return 0
  have=$(codium --list-extensions 2>/dev/null)
  while read -r id; do
    grep -qixF "$id" <<<"$have" && continue
    say "installing vscodium's $id"
    quiet codium --install-extension "$id" || warn "couldn't install $id"
  done < <(list "$DOTFILES/shared/vscodium-extensions.txt")
  vscodium_netcoredbg
}

vscodium_update() {
  local id
  have codium || return 0
  while read -r id; do
    quiet codium --install-extension "$id" --force || warn "couldn't update $id"
  done < <(list "$DOTFILES/shared/vscodium-extensions.txt")
  vscodium_netcoredbg
}

# vscodium_netcoredbg: c#'s debugger on an apple silicon mac. homebrew has no netcoredbg and mason's is
# an intel program, which a mac without rosetta can't run; the c# extension brings samsung's arm64 one,
# but unpacks it without its execute bit, so it can't run there either. this lets it run, for vscodium,
# and keeps a copy in ~/.local/opt/netcoredbg with a netcoredbg command in ~/.local/bin, for neovim
# (lua/plugins/csharp.lua): a copy, as vscodium updates the extension by itself, into a new folder, and
# a script for the command, as the debugger loads its library from beside the path it's started by,
# which for a link is the link's folder. of two versions the newer one's is used, and a netcoredbg of
# your own in ~/.local/bin stays
vscodium_netcoredbg() {
  local opt=$HOME/.local/opt/netcoredbg cmd=$HOME/.local/bin/netcoredbg src="" found
  [[ $(os_id) == macos && $(uname -m) == arm64 ]] || return 0
  for found in "$HOME"/.vscode-oss/extensions/muhammad-sammy.csharp-*/.debugger/netcoredbg/netcoredbg; do
    if [[ -f $found ]] && [[ -z $src || $found -nt $src ]]; then src=$found; fi
  done
  if [[ -z $src ]]; then
    warn "VSCodium's C# extension has no debugger in it, so C# can't be debugged: open a C# file in VSCodium, then run dot install again"
    return 0
  fi
  if [[ ! -x $src ]]; then
    say "letting vscodium's c# debugger run"
    chmod +x "$src" || warn "couldn't make $src executable"
  fi
  if ! cmp -s "$src" "$opt/netcoredbg"; then
    say "copying c#'s debugger for neovim"
    if ! { rm -rf "$opt.new" && mkdir -p "${opt%/*}" && cp -R "${src%/*}" "$opt.new" &&
      chmod +x "$opt.new/netcoredbg" && rm -rf "$opt" && mv "$opt.new" "$opt"; }; then
      rm -rf "$opt.new" || true
      warn "couldn't copy c#'s debugger to $opt"
      return 0
    fi
  fi
  [[ -x $opt/netcoredbg ]] || chmod +x "$opt/netcoredbg" || warn "couldn't make $opt/netcoredbg executable"
  # a link to nowhere at the command's path is nobody's program
  if [[ -L $cmd && ! -e $cmd ]]; then rm -f "$cmd" || true; fi
  if [[ ! -e $cmd && ! -L $cmd ]]; then
    { mkdir -p "${cmd%/*}" && vscodium_netcoredbg_command "$opt" >"$cmd" && chmod +x "$cmd"; } ||
      warn "couldn't write $cmd"
  fi
}

# vscodium_netcoredbg_command <folder>: the netcoredbg command's text, which runs the copy in that folder
vscodium_netcoredbg_command() {
  printf '#!/bin/sh\n# from the dotfiles (shared/vscodium.sh)\nexec "%s/netcoredbg" "$@"\n' "$1"
}

# vscodium_uninstall: the debugger's command and its copy, where install made them, which the command
# being the dotfiles' own tells: a netcoredbg of yours at either path stays
vscodium_uninstall() {
  local opt=$HOME/.local/opt/netcoredbg cmd=$HOME/.local/bin/netcoredbg
  [[ -f $cmd && ! -L $cmd ]] && cmp -s "$cmd" <(vscodium_netcoredbg_command "$opt") || return 0
  rm -f "$cmd"
  rm -rf "$opt"
}
