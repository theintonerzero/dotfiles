# tests/test_home.sh: the linked config files read right on both: the shell's path, git's logins, ghostty,
# and what claude is told about the machine
# shellcheck shell=bash
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
fresh_home() {
  rm -rf "$HOME"
  mkdir -p "$HOME"
}

for f in .zshenv .config/zsh/.zshrc .config/zsh/aliases.zsh .config/zsh/functions.zsh; do
  ok "zsh parses $f" zsh -n "$REPO/home/zsh/$f"
done
paths=$(zsh -f -c "source '$REPO/home/zsh/.zshenv'; print -l \$path")
eq "your scripts first" "$HOME/.local/bin" "$(sed -n 1p <<<"$paths")"
eq "then mise" "$HOME/.local/share/mise/shims" "$(sed -n 2p <<<"$paths")"
eq "then cargo" "$HOME/.cargo/bin" "$(sed -n 3p <<<"$paths")"
if [[ -d /opt/homebrew ]]; then
  eq "then homebrew" /opt/homebrew/bin "$(sed -n 4p <<<"$paths")"
  eq "homebrew once" 1 "$(grep -cx /opt/homebrew/bin <<<"$paths")"
  ok "zshrc looks in homebrew for the plugins" grep -q 'HOMEBREW_PREFIX' "$REPO/home/zsh/.config/zsh/.zshrc"
fi
ok "functions open with macos's open too" grep -q 'else open ' "$REPO/home/zsh/.config/zsh/functions.zsh"

# GIT_CONFIG_NOSYSTEM, from helpers.sh, matters here: homebrew's git sets osxkeychain for the whole system
helper() (
  load "$1"
  link_home >/dev/null
  git config --get-all credential.helper
  git config --get-urlmatch credential.helper https://github.com
)
eq "macos logins" "$(printf '%s\n' osxkeychain '!gh auth git-credential')" "$(helper macos)"
fresh_home
eq "fedora logins" "$(printf '%s\n' libsecret '!gh auth git-credential')" "$(helper fedora)"
ok "fedora's machine file" grep -q dnf "$HOME/.claude/machine.md"

fresh_home
(load macos && link_home) >/dev/null
ok "claude reads the machine file" grep -qxF '@~/.claude/machine.md' "$HOME/.claude/CLAUDE.md"
ok "mac machine file" grep -q Homebrew "$HOME/.claude/machine.md"
no "no dnf on the mac" grep -q dnf "$HOME/.claude/CLAUDE.md" "$HOME/.claude/machine.md"
ok "blender wrapper" test -x "$HOME/.local/bin/blender"
ok "option is alt" grep -qx 'macos-option-as-alt = true' "$HOME/.config/ghostty/os.conf"
ok "blurred" grep -qx 'background-blur = true' "$HOME/.config/ghostty/os.conf"
ok "a new ghostty window from anywhere, as super+enter gives fedora" \
  grep -qx 'keybind = global:ctrl+cmd+enter=new_window' "$HOME/.config/ghostty/os.conf"
ok "ghostty reads the os's file" grep -qx 'config-file = ?os.conf' "$HOME/.config/ghostty/config"
g=/Applications/Ghostty.app/Contents/MacOS/ghostty
if [[ -x $g ]]; then ok "ghostty accepts its config" "$g" +validate-config --config-file="$HOME/.config/ghostty/config"; fi

# git's everyday settings are the one file's, so both have them
for os in fedora macos; do
  fresh_home
  (load "$os" && link_home) >/dev/null
  eq "$os: branches newest first" -committerdate "$(git config branch.sort)"
  eq "$os: tags newest first" -version:refname "$(git config tag.sort)"
  eq "$os: rebase stashes" true "$(git config rebase.autoStash)"
  eq "$os: rebase squashes fixups" true "$(git config rebase.autoSquash)"
  eq "$os: rebase moves stacked branches" true "$(git config rebase.updateRefs)"
  eq "$os: the diff under the commit message" true "$(git config commit.verbose)"
  eq "$os: a mistyped command asks" prompt "$(git config help.autocorrect)"
  eq "$os: commits still signed" true "$(git config commit.gpgsign)"
  eq "$os: tags still signed" true "$(git config tag.gpgsign)"
done
