# tests/test_unity.sh: unity's script editor on each os, and where the unity cli lands on macos
# shellcheck shell=bash
# shellcheck disable=SC2016 # a stub's body is expanded when the stub runs
# shellcheck disable=SC2329 # steps a case isn't about are replaced by functions that say their name
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
D=com.unity3d.UnityEditor5.x
mkdir -p "$APPS/VSCodium.app"

# no editor chosen yet: vscodium, by a link with "code" in its path, as unity writes the c# project
# files only for an editor it takes for vs code, and it tells by the path
L=$HOME/.local/share/unity/code/VSCodium.app
(
  load macos
  stub pgrep 'exit 1'
  stub defaults '[[ $1 == read ]] && exit 1; exit 0'
  unity_editor >/dev/null
  eq "the link" "$APPS/VSCodium.app" "$(readlink "$L")"
  called "defaults write $D kScriptsDefaultApp -string $L"
)
# vscodium by its own path, as these dotfiles first set it: moved to the link
(
  load macos
  rm -rf "$HOME/.local/share/unity"
  stub pgrep 'exit 1'
  stub defaults '[[ $1 == read ]] && echo "$APPS/VSCodium.app"; exit 0'
  unity_editor >/dev/null
  eq "the link, again" "$APPS/VSCodium.app" "$(readlink "$L")"
  called "defaults write $D kScriptsDefaultApp -string $L"
)
# already the link: nothing to do
(
  load macos
  stub pgrep 'exit 1'
  stub defaults '[[ $1 == read ]] && echo "$HOME/.local/share/unity/code/VSCodium.app"; exit 0'
  eq "set already: nothing said" "" "$(unity_editor)"
  not_called "defaults write"
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
  rm -rf "$HOME/.local/share/unity"
  stub pgrep 'exit 1'
  stub defaults '[[ $1 == read ]] && exit 1; exit 0'
  unity_editor
  not_called "defaults write"
  no "no vscodium: no link" test -L "$L"
)
mkdir -p "$APPS/VSCodium.app"
# uninstall gives unity its own choice back, where the choice was ours, and takes the link away
(
  load macos
  mkdir -p "${L%/*}" && ln -sfn "$APPS/VSCodium.app" "$L"
  stub pgrep 'exit 1'
  stub defaults '[[ $1 == read ]] && echo "$HOME/.local/share/unity/code/VSCodium.app"; exit 0'
  unity_uninstall >/dev/null
  called "defaults delete $D kScriptsDefaultApp"
  no "link gone" test -L "$L"
  no "its folder gone" test -e "$HOME/.local/share/unity"
)
(
  load macos
  stub pgrep 'exit 1'
  stub defaults '[[ $1 == read ]] && echo /Applications/Rider.app; exit 0'
  unity_uninstall
  not_called "defaults delete"
)
# unity open at uninstall: the pref and the link both stay, as unity is using them
(
  load macos
  mkdir -p "${L%/*}" && ln -sfn "$APPS/VSCodium.app" "$L"
  stub pgrep 'exit 0'
  stub defaults '[[ $1 == read ]] && echo "$HOME/.local/share/unity/code/VSCodium.app"; exit 0'
  unity_uninstall 2>/dev/null
  not_called "defaults delete"
  ok "link kept" test -L "$L"
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
