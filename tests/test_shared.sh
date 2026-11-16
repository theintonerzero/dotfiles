# tests/test_shared.sh: the shared steps on macos: its commands, folders and process names, with fedora's
# side checked where the two part
# shellcheck shell=bash
# shellcheck disable=SC2016 # a stub's body is expanded when the stub runs
# shellcheck disable=SC2030,SC2031 # each case runs in a subshell of its own, on purpose
# shellcheck disable=SC2329 # steps a case isn't about are replaced by functions that do nothing
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

# the computer's name
(
  load macos
  stub scutil '[[ $1 == --get ]] && echo Zero'
  eq "reads the name" Zero "$(current_hostname)"
  eq "local name" Zeros-Mac "$(hostname_local "Zero's Mac")"
  NEW_HOSTNAME="Zero's Mac" set_hostname >/dev/null
  called "scutil --set ComputerName Zero's Mac"
  called "scutil --set LocalHostName Zeros-Mac"
  called "scutil --set HostName Zeros-Mac"
  : >"$T/calls"
  NEW_HOSTNAME=Zero set_hostname
  not_called "--set"
)

# the login shell
(
  load macos
  fzf_tab() { :; }
  atuin_import() { :; }
  btop_colours() { :; }
  stub dscl 'echo "UserShell: /bin/zsh"'
  shell_install
  not_called chsh
  stub dscl 'echo "UserShell: /bin/bash"'
  shell_install >/dev/null
  called "chsh -s /bin/zsh"
)

# rust, where homebrew has no rustup-init
(
  load macos
  stub_download 'exit 0'
  stub sh
  stub rustup-init
  toolchains_rust >/dev/null
  called "https://sh.rustup.rs"
  called "-y --no-modify-path --default-toolchain stable -c rust-analyzer -c rust-src"
  not_called "rustup-init -y"
)
(
  load fedora
  stub rustup-init
  toolchains_rust >/dev/null
  called "rustup-init -y --no-modify-path --default-toolchain stable -c rust-analyzer -c rust-src"
)

# mason's intel netcoredbg, which an apple silicon mac can't run: an earlier install's is taken away
(
  load macos
  stub nvim
  mason=$HOME/.local/share/nvim/mason/packages/netcoredbg
  stub uname 'case $1 in -m) echo arm64 ;; -s) echo Darwin ;; esac'
  neovim_netcoredbg
  not_called "MasonUninstall"
  mkdir -p "$mason"
  # neovim says a command went fine whether it did or not, so what counts is whether the folder went
  eq "one that stays is a warning" 1 "$(neovim_netcoredbg 2>&1 | grep -c "couldn't remove Mason's netcoredbg")"
  called "nvim --headless +MasonUninstall netcoredbg +qa"
  stub nvim 'rm -rf "$HOME/.local/share/nvim/mason/packages/netcoredbg"'
  no "one that goes isn't" grep -q "couldn't remove" <(neovim_netcoredbg 2>&1)
  mkdir -p "$mason"
  : >"$T/calls"
  stub uname 'case $1 in -m) echo x86_64 ;; -s) echo Darwin ;; esac'
  neovim_netcoredbg
  not_called "MasonUninstall"
  rm -f "$T/bin/uname"
  load fedora
  neovim_netcoredbg
  not_called "MasonUninstall"
  # install and update both come to it, once mason has installed its tools
  neovim_kotlin() { :; }
  neovim_netcoredbg() { echo netcoredbg; }
  eq "install comes to it" netcoredbg "$(neovim_install | tail -n 1)"
  eq "update too" netcoredbg "$(neovim_update | tail -n 1)"
)

# godot
eq "mac formatter" '^gdscript-formatter-.*-macos-aarch64\.zip$' "$(load macos && godot_formatter_asset)"
eq "fedora formatter" '^gdscript-formatter-.*-linux-x86_64\.zip$' "$(load fedora && godot_formatter_asset)"
(
  load macos
  stub godot 'echo 4.7.2.stable.official'
  stub pgrep 'exit 1'
  godot_settings >/dev/null
  f="$HOME/Library/Application Support/Godot/editor_settings-4.7.tres"
  ok "godot's settings on the mac" grep -qxF "text_editor/external/exec_path = \"$HOME/.local/bin/godot-nvim\"" "$f"
  stub pgrep '[[ $2 == Godot ]]'
  rm -f "$f"
  godot_settings
  no "godot open, settings left" test -e "$f"
)

# lm studio, open under its macos name
(
  load macos
  mkdir -p "$HOME/.lmstudio"
  echo '{}' >"$HOME/.lmstudio/settings.json"
  stub pgrep '[[ $2 == "LM Studio" ]]'
  lmstudio_settings
  [[ ${TODOS[*]} == *"quit LM Studio"* ]] || fail "lm studio open: a todo"
  eq "lm studio's settings left while it's open" '{}' "$(cat "$HOME/.lmstudio/settings.json")"
)

# blender's folder, for the mcp add-ons
(
  load macos
  stub pgrep 'exit 1'
  stub uvx
  stub blender '[[ $1 == --version ]] && echo "Blender 5.3.0"'
  claude_blender >/dev/null 2>&1 || true
  called "--addons-dir $HOME/Library/Application Support/Blender/5.3/scripts/addons"
)
(
  mkdir -p "$HOME/Library/Application Support/Blender/5.3/extensions/blender_lab/mcp"
  echo 'version = "1.2.0"' >"$HOME/Library/Application Support/Blender/5.3/extensions/blender_lab/mcp/blender_manifest.toml"
  stub uname 'echo Darwin'
  stub git
  stub uvx
  "$REPO/home/claude/.local/bin/blender-lab-mcp"
  called "blender_mcp.git@v1.2.0"
)
rm -f "$T/bin/uname" "$T/bin/git" "$T/bin/uvx"

# playwright's chromium, where macos caches it
(
  load macos
  for c in claude cargo npx uvx; do stub "$c"; done
  stub gh 'exit 1'
  stub_download ''
  stub blender 'echo "Blender 4.0.0"'
  stub pgrep 'exit 1'
  mkdir -p "$HOME/Library/Caches/ms-playwright/chromium-1"
  claude_servers >/dev/null 2>&1
  not_called "install-browser"
)
(
  load macos
  for c in claude cargo npx uvx; do stub "$c"; done
  stub gh 'exit 1'
  stub_download ''
  stub blender 'echo "Blender 4.0.0"'
  stub pgrep 'exit 1'
  rm -rf "$HOME/Library/Caches/ms-playwright"
  mkdir -p "$HOME/.cache/ms-playwright/chromium-1"
  claude_servers >/dev/null 2>&1
  called "install-browser chromium"
)

# godot-nvim: a new ghostty window, as each os opens one
mkdir -p "$T/proj"
touch "$T/proj/project.godot"
stub nvim 'exit 1'
stub git 'exit 1'
stub uname 'echo Darwin'
stub open
"$REPO/home/godot/.local/bin/godot-nvim" "$T/proj" "$T/proj/a.gd" 3 1
called "open -na Ghostty.app --args --quit-after-last-window-closed=true -e nvim"
stub uname 'echo Linux'
stub ghostty
"$REPO/home/godot/.local/bin/godot-nvim" "$T/proj" "$T/proj/a.gd" 3 1
called "ghostty +new-window -e nvim"
# with no XDG_RUNTIME_DIR, as on macos, a neovim serving the project is still found, under ~/.local/state;
# a socket's path can't be long, so this home is a short one
short=$(mktemp -d /tmp/dot.XXXXXX)
stub uname 'echo Darwin'
sum=$(printf '%s' "$T/proj" | sha256sum)
mkdir -p "$short/.local/state/godot-nvim"
python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$short/.local/state/godot-nvim/${sum:0:16}.sock"
stub nvim 'exit 0'
: >"$T/calls"
HOME=$short "$REPO/home/godot/.local/bin/godot-nvim" "$T/proj" "$T/proj/a.gd" 3 1
rm -rf "$short"
called "nvim --server $short/.local/state/godot-nvim/${sum:0:16}.sock --remote-expr"
not_called "open -na"
ok "lua agrees on the socket" grep -qF 'XDG_RUNTIME_DIR or (vim.env.HOME .. "/.local/state")' "$REPO/home/nvim/.config/nvim/lua/godot.lua"


# blender's launcher is linked on macos whether or not the app is there: without it the step stops
# quietly, and the run goes on
(
  load macos
  set -euo pipefail
  stub blender 'exit 127'
  claude_blender
  echo reached >"$T/reached"
)
ok "no blender app: the run goes on" test -f "$T/reached"

# fedora: an update that moved the gtk package gives flatpak apps the new folder, not only install
(
  load fedora
  apps_releases() { :; }
  font_install() { :; }
  stub flatpak '[[ "$*" == "override --user --show" ]] && printf "%s\n" "filesystems=$DOTFILES/home/gtk:ro;xdg-config/gtk-4.0:ro;"; exit 0'
  apps_update >/dev/null 2>&1
  called "flatpak override --user --filesystem=xdg-config/gtk-4.0:ro --filesystem=xdg-config/gtk-3.0:ro --filesystem=$DOTFILES/fedora/home/gtk:ro"
)
