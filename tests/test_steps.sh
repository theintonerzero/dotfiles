# tests/test_steps.sh: the order each os runs its steps in, and the entry scripts' start
# shellcheck shell=bash
# shellcheck disable=SC2016 # a stub's body is expanded when the stub runs
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

# order <os> <function>: the steps the function runs, in order, each step standing in for itself by name
order() (
  load "$1"
  for f in $(declare -F | awk '{ print $3 }' |
    grep -E '_(install|update|uninstall)$|^(ask_questions|keep_sudo|set_hostname|link_home|unlink_home|system_first|gui_env|not_root|neovim_parsers)$'); do
    [[ $f == os_* ]] || eval "$f() { echo $f; }"
  done
  "$2" | grep -E '^[a-z_]+$' | tr '\n' ' '
)

eq "fedora install" "ask_questions keep_sudo set_hostname system_install apps_install link_home shell_install git_install toolchains_install neovim_install vscodium_install godot_install unity_install claude_install gnome_install gaming_install llm_install " "$(order fedora os_install)"
eq "fedora update" "keep_sudo system_update apps_update link_home shell_update toolchains_update neovim_update vscodium_update unity_update claude_update godot_update gnome_update gaming_update llm_update " "$(order fedora os_update)"
eq "fedora uninstall" "unlink_home gaming_uninstall apps_uninstall neovim_uninstall godot_uninstall unity_uninstall " "$(order fedora os_uninstall)"
ok "fedora's note survives" grep -q "the packages, Flatpaks and repos install added" <<<"$(load fedora && os_uninstall_notes)"

for f in lib.sh install.sh update.sh uninstall.sh bin/dot; do ok "bash 3.2 parses $f" /bin/bash -n "$REPO/$f"; done
for f in install.sh update.sh uninstall.sh; do
  ok "$f starts by finding a new enough bash" grep -qx 'need_bash "$@"' "$REPO/$f"
  no "$f names no os" grep -qE 'fedora|macos' <(grep -v '^#' "$REPO/$f" | grep -v 'die ')
done

# on a mac with only bash 3.2, a script hands itself to homebrew's bash
if [[ $(/bin/bash -c 'echo ${BASH_VERSINFO[0]}') -lt 4 ]]; then
  printf '#!/bin/sh\necho "re-exec $*"\n' >"$T/newbash"
  chmod +x "$T/newbash"
  out=$(DOT_OS=macos DOT_BREW_BASH="$T/newbash" /bin/bash -c "source '$REPO/lib.sh'; brew_bootstrap() { :; }; need_bash a b" script 2>&1)
  eq "re-exec" "re-exec script a b" "$out"
fi
lib
ok "a new enough bash carries on" need_bash

# an update that pulled new commits starts again, as the new scripts
cat >"$T/up.sh" <<EOF
#!/usr/bin/env bash
source "$REPO/lib.sh"
PATH=$T/bin:\$PATH
echo run >>"$T/runs"
pull_dotfiles
echo finished
EOF
chmod +x "$T/up.sh"
stub git 'if [[ "$*" == *"rev-parse HEAD" ]]; then
  n=$(cat "$T/n" 2>/dev/null || echo 0); echo $((n + 1)) >"$T/n"
  if ((n < 1)); then echo before; else echo after; fi
fi'
eq "update finishes" finished "$("$T/up.sh" | tail -n 1)"
eq "after starting again once" 2 "$(grep -c run "$T/runs")"

# macos's order; dot update sets none of the system's settings
eq "macos install" "system_first ask_questions keep_sudo set_hostname system_install apps_install link_home gui_env shell_install git_install toolchains_install neovim_install vscodium_install godot_install unity_install claude_install desktop_install bar_install security_install llm_install " "$(order macos os_install)"
eq "macos update" "keep_sudo system_update apps_update link_home bar_update shell_update toolchains_update neovim_update vscodium_update unity_update claude_update godot_update llm_update " "$(order macos os_update)"
eq "macos uninstall" "unlink_home apps_uninstall bar_uninstall neovim_uninstall vscodium_uninstall godot_uninstall unity_uninstall " "$(order macos os_uninstall)"
ok "macos says what uninstall leaves" grep -q "Homebrew" <<<"$(load macos && os_uninstall_notes)"

ok "readme has the mac's steps" grep -q 'brew install gh' "$REPO/README.md"
no "readme no longer says not yet for macos" grep -q '| macOS | Not yet |' "$REPO/README.md"
ok "readme lists the mac's lists" grep -q 'macos/defaults.txt' "$REPO/README.md"
ok "readme has the mac's bar" grep -q '^| Bar, on macOS |' "$REPO/README.md"
ok "readme lists the taps" grep -q 'macos/taps.txt' "$REPO/README.md"
ok "changelog says sketchybar" grep -q 'sketchybar' <(sed -n '/^## \[Unreleased\]/,/^## \[1\./p' "$REPO/CHANGELOG.md")
ok "changelog says macos" grep -q 'macOS' <(sed -n '/^## \[Unreleased\]/,/^## \[1\./p' "$REPO/CHANGELOG.md")

# ubuntu server's order: it asks nothing, signs in to nothing, and sets up no desktop
eq "ubuntu install" "not_root keep_sudo system_install tools_install link_home shell_install neovim_install neovim_parsers " "$(NEOVIM_CMD=true order ubuntu os_install)"
eq "ubuntu update" "not_root keep_sudo system_update tools_update link_home shell_update neovim_update neovim_parsers " "$(NEOVIM_CMD=true order ubuntu os_update)"
eq "ubuntu uninstall" "not_root unlink_home neovim_uninstall " "$(order ubuntu os_uninstall)"
ok "readme has ubuntu's steps" grep -q 'sudo apt-get install -y git' "$REPO/README.md"
ok "readme clones over https on ubuntu, with no sign-in" grep -qF 'git clone https://github.com/theintonerzero/dotfiles ~/dotfiles' "$REPO/README.md"
no "readme no longer says not yet for ubuntu" grep -q 'Ubuntu Server.*Not yet' "$REPO/README.md"
ok "readme lists ubuntu's lists" grep -q 'ubuntu/tools.txt' "$REPO/README.md"
ok "readme names the container test" grep -q 'tests/container.sh' "$REPO/README.md"
ok "changelog says ubuntu server" grep -q 'Ubuntu Server' <(sed -n '/^## \[Unreleased\]/,/^## \[1\./p' "$REPO/CHANGELOG.md")
notes=$(load ubuntu && os_uninstall_notes)
ok "ubuntu says apt's packages stay" grep -q "apt" <<<"$notes"
ok "ubuntu says the release tools stay" grep -qF '.local/opt' <<<"$notes"

# the sign-ins install ends on are each desktop os's own; a server has none
for os in fedora macos; do
  (load "$os" && os_signins && [[ ${TODOS[*]} == *"sign in to Claude (claude), Copilot (:Copilot auth in Neovim), Spotify and Vesktop"* ]]) ||
    fail "$os still ends on its sign-ins"
done
no "ubuntu has no sign-ins" bash -c "source '$REPO/tests/helpers.sh'; trap - ERR; load ubuntu; declare -F os_signins >/dev/null"
ok "install asks the os for its sign-ins" grep -q 'os_signins' "$REPO/install.sh"
no "install names no app itself" grep -q 'Spotify' "$REPO/install.sh"
for f in install.sh update.sh uninstall.sh; do
  out=$(DOT_OS=unknown "$BASH" "$REPO/$f" 2>&1) && fail "$f on an os it doesn't know: stops"
  [[ $out == *"these dotfiles support Fedora, macOS and Ubuntu Server"* ]] || fail "$f names the three it supports: $out"
done
