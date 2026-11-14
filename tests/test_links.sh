# tests/test_links.sh: link_home and unlink_home: what each os links, and a home linked by the older layout
# shellcheck shell=bash
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
real() { readlink -f "$1"; }
fresh_home() {
  rm -rf "$HOME"
  mkdir -p "$HOME"
}

# fedora links what it always did, from the new places
(load fedora && link_home) >/dev/null
eq "gtk" "$REPO/fedora/home/gtk/.config/gtk-4.0/gtk.css" "$(real "$HOME/.config/gtk-4.0/gtk.css")"
eq "vscodium" "$REPO/shared/vscodium-settings.json" "$(real "$HOME/.config/VSCodium/User/settings.json")"
ok "x-terminal-emulator" test -x "$HOME/.local/bin/x-terminal-emulator"
ok "xdg-terminals.list" test -f "$HOME/.config/xdg-terminals.list"
ok "environment.d" test -f "$HOME/.config/environment.d/10-dotfiles.conf"
ok "steam-apps" test -x "$HOME/.local/bin/steam-apps"
ok "dot" test -L "$HOME/.local/bin/dot"
no "nothing mac-only" test -e "$HOME/Library"

# a fedora home linked by the old layout heals itself, with no .bak left behind
fresh_home
mkdir -p "$HOME/.config/gtk-4.0" "$HOME/.config/VSCodium/User"
ln -s "$REPO/home/gtk/.config/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
ln -s "$REPO/home/vscodium/.config/VSCodium/User/settings.json" "$HOME/.config/VSCodium/User/settings.json"
(load fedora && link_home) >/dev/null
eq "gtk relinked" "$REPO/fedora/home/gtk/.config/gtk-4.0/gtk.css" "$(real "$HOME/.config/gtk-4.0/gtk.css")"
eq "vscodium relinked" "$REPO/shared/vscodium-settings.json" "$(real "$HOME/.config/VSCodium/User/settings.json")"
eq "no backups" "" "$(find "$HOME" -name '*.bak*')"

# macos links nothing linux-only
fresh_home
(load macos && link_home) >/dev/null
for p in .config/gtk-4.0 .config/gtk-3.0 .config/systemd .config/environment.d .config/xdg-terminals.list \
  .local/bin/x-terminal-emulator .local/bin/steam-apps .config/VSCodium; do
  no "no $p on macos" test -e "$HOME/$p"
done
eq "vscodium on macos" "$REPO/shared/vscodium-settings.json" \
  "$(real "$HOME/Library/Application Support/VSCodium/User/settings.json")"
ok "nvim still linked" test -f "$HOME/.config/nvim/init.lua"

# your own file where a link goes, at a path with a space, is kept and comes back
fresh_home
mkdir -p "$HOME/Library/Application Support/VSCodium/User"
echo mine >"$HOME/Library/Application Support/VSCodium/User/settings.json"
(load macos && link_home) >/dev/null
eq "kept" mine "$(cat "$HOME/Library/Application Support/VSCodium/User/settings.json.bak")"
ok "linked over it" test -L "$HOME/Library/Application Support/VSCodium/User/settings.json"
(load macos && unlink_home) >/dev/null
eq "restored" mine "$(cat "$HOME/Library/Application Support/VSCodium/User/settings.json")"
no "nvim unlinked" test -e "$HOME/.config/nvim/init.lua"

# a dead link to somewhere else isn't ours to delete
fresh_home
mkdir -p "$HOME/.config/git"
ln -s /nowhere/config "$HOME/.config/git/config"
(load macos && link_home) >/dev/null
ok "foreign dead link kept as .bak" test -L "$HOME/.config/git/config.bak"
