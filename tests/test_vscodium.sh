# tests/test_vscodium.sh: vscodium's vim keys, as astronvim has them, and the c# server unity's
# projects need; the same files on fedora and macos
# shellcheck shell=bash
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
