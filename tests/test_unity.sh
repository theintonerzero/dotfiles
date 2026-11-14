# tests/test_unity.sh: unity's script editor on each os, and where the unity cli lands on macos
# shellcheck shell=bash
# shellcheck disable=SC2016 # a stub's body is expanded when the stub runs
# shellcheck disable=SC2329 # steps a case isn't about are replaced by functions that say their name
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
D=com.unity3d.UnityEditor5.x
mkdir -p "$APPS/VSCodium.app"

# no editor chosen yet: vscodium
(
  load macos
  stub pgrep 'exit 1'
  stub defaults '[[ $1 == read ]] && exit 1; exit 0'
  unity_editor >/dev/null
  called "defaults write $D kScriptsDefaultApp -string $APPS/VSCodium.app"
)
# an editor of your own stays
(
  load macos
  stub pgrep 'exit 1'
  stub defaults '[[ $1 == read ]] && echo /Applications/Rider.app; exit 0'
  unity_editor
  not_called "defaults write"
)
# unity open: it would write its own prefs back, so this waits
(
  load macos
  stub pgrep 'exit 0'
  stub defaults '[[ $1 == read ]] && exit 1; exit 0'
  unity_editor
  not_called "defaults write"
  [[ ${TODOS[*]} == *"close Unity"*VSCodium* ]] || fail "unity open: a todo"
)
# no vscodium, nothing to point unity at
(
  load macos
  rmdir "$APPS/VSCodium.app"
  stub pgrep 'exit 1'
  stub defaults '[[ $1 == read ]] && exit 1; exit 0'
  unity_editor
  not_called "defaults write"
)
mkdir -p "$APPS/VSCodium.app"
# uninstall gives unity its own choice back, where the choice was ours
(
  load macos
  stub pgrep 'exit 1'
  stub defaults '[[ $1 == read ]] && echo "$APPS/VSCodium.app"; exit 0'
  unity_uninstall >/dev/null
  called "defaults delete $D kScriptsDefaultApp"
)
(
  load macos
  stub pgrep 'exit 1'
  stub defaults '[[ $1 == read ]] && echo /Applications/Rider.app; exit 0'
  unity_uninstall
  not_called "defaults delete"
)
# fedora stays on neovim
(
  load fedora
  unity_neovim() { echo neovim; }
  unity_vscodium() { echo vscodium; }
  eq "fedora's editor" neovim "$(unity_editor)"
)
ok "unity-project sets the os's editor" grep -qx 'unity_editor' "$REPO/home/unity/.local/bin/unity-project"

# the cli, which unity's installer puts in ~/.unity on macos, is still at ~/.local/bin/unity
(
  load macos
  stub_download 'mkdir -p "$HOME/.unity/bin"; printf "#!/bin/sh\n" >"$HOME/.unity/bin/unity"; chmod +x "$HOME/.unity/bin/unity"'
  unity_cli >/dev/null
  eq "cli linked" "$HOME/.unity/bin/unity" "$(readlink "$HOME/.local/bin/unity")"
  [[ ${#TODOS[@]} == 0 ]] || fail "cli installed: no todo"
)
