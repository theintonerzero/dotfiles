# shared/vscodium.sh: vscodium's extensions, from open vsx; its settings are linked
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
}

vscodium_update() {
  local id
  have codium || return 0
  while read -r id; do
    quiet codium --install-extension "$id" --force || warn "couldn't update $id"
  done < <(list "$DOTFILES/shared/vscodium-extensions.txt")
}
