# tests/test_vscodium.sh: vscodium's vim keys, as astronvim has them, and the c# server unity's
# projects need; the same files on fedora and macos
# shellcheck shell=bash
# shellcheck disable=SC2016 # a stand-in program's text is expanded when it runs
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
real() { readlink -f "$1"; }
S=$REPO/shared/vscodium-settings.json
K=$REPO/shared/vscodium-keybindings.json

ok "the vim extension is listed" grep -qx 'vscodevim.vim' "$REPO/shared/vscodium-extensions.txt"
ok "unity's snippets are listed" grep -qx 'kleber-swf.unity-code-snippets' "$REPO/shared/vscodium-extensions.txt"
# clangd's extension has no debugger, so c and c++ get the one neovim uses; cmake's brings its language
ok "a c and c++ debugger is listed" grep -qx 'vadimcn.vscode-lldb' "$REPO/shared/vscodium-extensions.txt"
ok "cmake's extension is listed" grep -qx 'ms-vscode.cmake-tools' "$REPO/shared/vscodium-extensions.txt"
ok "fedora has cmake" grep -qx 'cmake' "$REPO/fedora/packages.txt"
# json <filter> <file>: whether the file is json that the filter holds for, saying nothing
json() { jq -e "$1" "$2" >/dev/null 2>&1; }
ok "settings are json" json 'type == "object"' "$S"
ok "keybindings are json" json 'type == "array"' "$K"

# keys <mode>: every key sequence the settings bind in that mode, one per line, as vim writes them
keys() { jq -r --arg m "$1" '.[$m][] | .before | join("")' "$S"; }
# does <mode> <keys>: the vscodium command, or the vim keys, that sequence runs
does() {
  jq -r --arg m "$1" --arg k "$2" \
    '.[$m][] | select((.before | join("")) == $k) | (.commands // .after) | map(if type == "object" then .command else . end) | join(" ")' "$S"
}
N=vim.normalModeKeyBindingsNonRecursive V=vim.visualModeKeyBindingsNonRecursive I=vim.insertModeKeyBindings

# astronvim's leader, clipboard, search and escape
eq "leader" "<space>" "$(jq -r '."vim.leader"' "$S")"
eq "system clipboard" true "$(jq -r '."vim.useSystemClipboard"' "$S")"
eq "ignorecase" true "$(jq -r '."vim.ignorecase"' "$S")"
eq "smartcase" true "$(jq -r '."vim.smartcase"' "$S")"
eq "surround" true "$(jq -r '."vim.surround"' "$S")"
eq "jj leaves insert mode" "<Esc>" "$(does "$I" jj)"
eq "jk leaves insert mode" "<Esc>" "$(does "$I" jk)"

# a sample of astronvim's own mappings, each on the command that does the same in vscodium
eq "save" workbench.action.files.save "$(does "$N" '<leader>w')"
eq "close buffer" workbench.action.closeActiveEditor "$(does "$N" '<leader>c')"
eq "explorer" workbench.action.toggleSidebarVisibility "$(does "$N" '<leader>e')"
eq "find files" workbench.action.quickOpen "$(does "$N" '<leader>ff')"
eq "find words" workbench.action.findInFiles "$(does "$N" '<leader>fw')"
eq "comment line" editor.action.commentLine "$(does "$N" '<leader>/')"
eq "comment selection" editor.action.commentLine "$(does "$V" '<leader>/')"
eq "next buffer" workbench.action.nextEditorInGroup "$(does "$N" ']b')"
eq "code action" editor.action.quickFix "$(does "$N" '<leader>la')"
eq "rename" editor.action.rename "$(does "$N" '<leader>lr')"
eq "format" editor.action.formatDocument "$(does "$N" '<leader>lf')"
eq "split left" workbench.action.navigateLeft "$(does "$N" '<C-h>')"
eq "vertical split" workbench.action.splitEditorRight "$(does "$N" '|')"
eq "breakpoint" editor.debug.action.toggleBreakpoint "$(does "$N" '<leader>db')"

# no key sequence bound twice in a mode, and none that is the start of another, which vim would have
# to wait on
for m in "$N" "$V"; do
  eq "$m: nothing bound twice" "" "$(keys "$m" | sort | uniq -d)"
  while read -r k; do
    [[ -z $(keys "$m" | grep -vxF -- "$k" | grep -F -- "$k" | awk -v k="$k" 'index($0, k) == 1') ]] ||
      fail "$m: $k is the start of another binding"
  done < <(keys "$m")
done

# outside the editor, where the vim extension doesn't reach: the explorer's keys and the splits
kb() { jq -r --arg k "$1" '.[] | select(.key == $k) | .command' "$K" | sort -u | paste -sd' ' -; }
eq "explorer down" list.focusDown "$(kb j)"
eq "explorer new file" explorer.newFile "$(kb a)"
eq "terminal toggle" workbench.action.terminal.toggleTerminal "$(kb f7)"
eq "back to the editor" workbench.action.navigateRight "$(kb ctrl+l)"
eq "every key outside the editor says where it applies" 0 \
  "$(jq '[.[] | select(.key | test("^(f7|ctrl\\+.)$") | not) | select(.when == null)] | length' "$K")"
eq "no letter is taken while typing" 0 \
  "$(jq '[.[] | select(.key | test("^(shift\\+)?[a-z/]$|^enter$|^space ")) | select(.when | test("!inputFocus") | not)] | length' "$K")"

# unity writes a .slnx, which omnisharp can't open; the extension's other server can
eq "roslyn, not omnisharp" false "$(jq -r '."dotnet.server.useOmnisharp"' "$S")"

# both files reach each os's vscodium
(load fedora && link_home) >/dev/null
eq "fedora keybindings" "$K" "$(real "$HOME/.config/VSCodium/User/keybindings.json")"
eq "fedora settings" "$S" "$(real "$HOME/.config/VSCodium/User/settings.json")"
rm -rf "$HOME" && mkdir -p "$HOME"
(load macos && link_home) >/dev/null
eq "macos keybindings" "$K" "$(real "$HOME/Library/Application Support/VSCodium/User/keybindings.json")"

# --- c#'s debugger on an apple silicon mac ---
# mason has only an intel netcoredbg for a mac, so neovim runs the arm64 one the c# extension brings,
# which the extension unpacks without its execute bit; the step mends that and keeps a copy for neovim

EXT=$HOME/.vscode-oss/extensions
OPT=$HOME/.local/opt/netcoredbg
CMD=$HOME/.local/bin/netcoredbg
fresh() { rm -rf "$HOME" && mkdir -p "$HOME"; }
# mac <processor>: macos's steps, on a mac with that processor
mac() {
  load macos
  stub uname "case \$1 in -m) echo $1 ;; -s) echo Darwin ;; esac"
}
# extension <version>: a c# extension as vscodium unpacks it, its debugger in a folder of its own and not
# executable. like the real one, it loads a library from beside the path it was started by, a link's own
# folder when started through a link, and says which version it came with
extension() {
  local dir=$EXT/muhammad-sammy.csharp-$1-darwin-arm64/.debugger/netcoredbg
  mkdir -p "$dir"
  printf '#!/bin/sh\n[ -f "$(dirname "$0")/libdbgshim.dylib" ] || { echo "Unable to load libdbgshim.dylib" >&2; exit 1; }\necho "netcoredbg from %s"\n' "$1" >"$dir/netcoredbg"
  chmod 644 "$dir/netcoredbg"
  echo shim >"$dir/libdbgshim.dylib"
  echo "$dir/netcoredbg"
}

(
  fresh && mac arm64
  src=$(extension 2.0.0)
  vscodium_netcoredbg >/dev/null
  ok "the extension's debugger can run, for vscodium" test -x "$src"
  ok "neovim's copy can run" test -x "$OPT/netcoredbg"
  ok "and is the same program" cmp -s "$src" "$OPT/netcoredbg"
  ok "with the library it loads" test -f "$OPT/libdbgshim.dylib"
  eq "the command runs the copy, which finds its library" "netcoredbg from 2.0.0" "$("$CMD")"
  no "and is no link, as the debugger would look beside the link" test -L "$CMD"

  before=$(ls -di "$OPT")
  eq "a second run says nothing" "" "$(vscodium_netcoredbg 2>&1)"
  eq "and copies nothing" "$before" "$(ls -di "$OPT")"

  # vscodium updates an extension by itself, into a new folder, and the old one goes
  touch -t 202601010000 "$src"
  new=$(extension 2.1.0)
  vscodium_netcoredbg >/dev/null
  eq "of two versions, the newer one's debugger" "netcoredbg from 2.1.0" "$("$CMD")"
  ok "which can run for vscodium too" test -x "$new"
  no "no half-made copy is left" test -e "$OPT.new"
  rm -rf "$EXT"
  eq "the extension gone, neovim's copy still runs" "netcoredbg from 2.1.0" "$("$CMD")"
  ok "and the step carries on" vscodium_netcoredbg 2>/dev/null
  ok "saying what's missing" grep -q "C# extension" <(vscodium_netcoredbg 2>&1)

  vscodium_uninstall
  no "uninstall removes the command" test -e "$CMD"
  no "and the copy" test -e "$OPT"
)
(
  fresh && mac arm64
  mkdir -p "$EXT/muhammad-sammy.csharp-2.0.0-darwin-arm64"
  ok "an extension with no debugger: the step carries on" vscodium_netcoredbg 2>/dev/null
  ok "saying what's missing" grep -q "C# extension" <(vscodium_netcoredbg 2>&1)
  no "and nothing is made" test -e "$OPT"
  no "nor a command" test -e "$CMD"
)
(
  # a netcoredbg of your own stays yours
  fresh && mac arm64
  extension 2.0.0 >/dev/null
  mkdir -p "${CMD%/*}"
  echo mine >"$CMD"
  vscodium_netcoredbg >/dev/null 2>&1
  eq "your own netcoredbg is left by install" mine "$(cat "$CMD")"
  vscodium_uninstall
  eq "and by uninstall" mine "$(cat "$CMD")"
)
(
  # by when it was unpacked, not by its name: 2.9.0 comes after 2.10.0 in a listing
  fresh && mac arm64
  touch -t 202601010000 "$(extension 2.9.0)"
  extension 2.10.0 >/dev/null
  vscodium_netcoredbg >/dev/null
  eq "the newer version, whatever its name sorts as" "netcoredbg from 2.10.0" "$("$CMD")"
)
(
  # a link to nowhere at the command's path is nobody's program
  fresh && mac arm64
  extension 2.0.0 >/dev/null
  mkdir -p "${CMD%/*}"
  ln -s "$T/gone/netcoredbg" "$CMD"
  vscodium_netcoredbg >/dev/null
  eq "a link to nowhere gives way to the command" "netcoredbg from 2.0.0" "$("$CMD")"
)
(
  # a ~/.local/opt/netcoredbg install never made, as on a mac the step does nothing on, is yours
  fresh && mac x86_64
  mkdir -p "$OPT"
  printf '#!/bin/sh\n' >"$OPT/netcoredbg"
  chmod +x "$OPT/netcoredbg"
  vscodium_uninstall
  ok "uninstall leaves a netcoredbg folder it didn't make" test -x "$OPT/netcoredbg"
)
(
  # install and update stop at the first failure, so a copy that can't be put in place is a warning
  fresh && mac arm64
  extension 2.0.0 >/dev/null
  stub mv 'exit 1'
  out=$(DOT_OS=macos "$BASH" -c 'set -euo pipefail; source "$REPO/lib.sh"; PATH=$T/bin:$PATH; load_steps macos; vscodium_netcoredbg; echo carried on' 2>&1) || true
  rm -f "$T/bin/mv"
  ok "a copy that can't be moved into place doesn't end the run" grep -qx 'carried on' <<<"$out"
  ok "and is a warning" grep -q "couldn't copy" <<<"$out"
  no "with nothing half made left" test -e "$OPT.new"
)
(
  fresh && mac x86_64
  src=$(extension 2.0.0)
  vscodium_netcoredbg
  no "an intel mac keeps mason's: no copy" test -e "$OPT"
  no "and the extension is left alone" test -x "$src"
)
(
  fresh && mac arm64
  extension 2.0.0 >/dev/null
  stub codium
  vscodium_install >/dev/null
  ok "install runs the step" test -x "$OPT/netcoredbg"
  rm -rf "$OPT"
  vscodium_update >/dev/null
  ok "update does too" test -x "$OPT/netcoredbg"
)
rm -f "$T/bin/uname"
(
  fresh && load fedora
  src=$(extension 2.0.0)
  vscodium_netcoredbg
  no "fedora keeps mason's: no copy" test -e "$OPT"
)
