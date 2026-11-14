# tests/test_ubuntu.sh: ubuntu server: what it links, that it won't run as root, apt's packages, and each
# tool from apt or from its own release
# shellcheck shell=bash
# shellcheck disable=SC2016 # a stub's body is expanded when the stub runs
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
fresh_home() {
  rm -rf "$HOME"
  mkdir -p "$HOME"
}

# a server links the shell, git, tmux, neovim, the prompt and the small tools' config, and dot
(load ubuntu && link_home) >/dev/null
for p in .zshenv .config/zsh/.zshrc .config/git/config .config/tmux/tmux.conf .config/sesh/sesh.toml \
  .config/nvim/init.lua .config/starship.toml .config/lazygit/config.yml .config/atuin/config.toml .local/bin/dot; do
  ok "ubuntu links $p" test -e "$HOME/$p"
done
# and nothing a desktop or a development machine has
for p in .claude .config/ghostty .config/mise .local/bin/godot-nvim .local/bin/unity-project \
  .local/bin/blender-lab-mcp .config/gtk-4.0 .config/VSCodium Library; do
  no "ubuntu links no $p" test -e "$HOME/$p"
done
(load ubuntu && unlink_home) >/dev/null
no "unlinked" test -e "$HOME/.config/zsh/.zshrc"
no "nothing left linked into the repo" bash -c "find '$HOME' -type l -lname '$REPO/*' | grep -q ."

# the list names only packages there are
(
  load ubuntu
  while read -r pkg; do ok "home.txt's $pkg is a package" test -d "$REPO/home/$pkg"; done < <(list "$REPO/ubuntu/home.txt")
)
# fedora and macos still link every shared package
fresh_home
(load fedora && link_home) >/dev/null
ok "fedora still links claude's settings" test -e "$HOME/.claude/CLAUDE.md"
ok "fedora still links mise" test -e "$HOME/.config/mise/config.toml"

# install set up your own home, so it won't run as root, and stops before it does anything
out=$( (load ubuntu && not_root 0) 2>&1) && fail "as root: install stops"
[[ $out == *"not as root"* ]] || fail "as root: says why: $out"
eq "as root: nothing run" "" "$(calls)"
ok "as yourself: carries on" bash -c "source '$REPO/tests/helpers.sh'; load ubuntu; not_root 1000"

# apt: only what's missing is asked for, in one call, with no recommended extras
(
  load ubuntu
  stub dpkg-query '[[ ${*: -1} == zsh ]] && printf installed; exit 0'
  apt_packages >/dev/null
  eq "one install" 1 "$(calls | grep -c 'apt-get install')"
  called "sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends"
  line=$(calls | grep 'apt-get install')
  while read -r pkg; do
    if [[ $pkg == zsh ]]; then
      [[ " $line " != *" zsh "* ]] || fail "zsh is there already, so it isn't asked for"
    else
      [[ " $line " == *" $pkg "* ]] || fail "$pkg is asked for"
    fi
  done < <(list "$REPO/ubuntu/packages.txt")
)
(
  load ubuntu
  stub dpkg-query 'printf installed'
  apt_packages
  not_called "apt-get install"
)
(
  load ubuntu
  while read -r pkg; do [[ $pkg =~ ^[a-z0-9][a-z0-9.+-]+$ ]] || fail "packages.txt: $pkg isn't a package name"; done < <(list "$REPO/ubuntu/packages.txt")
  ok "a compiler, for neovim's parsers" grep -qx gcc <(list "$REPO/ubuntu/packages.txt")
)
# the package lists are fetched when there are none or they're a day old, and always for an update
(
  load ubuntu
  APT_LISTS=$T/lists
  mkdir -p "$APT_LISTS"
  apt_refresh >/dev/null
  called "sudo apt-get update"
  touch "$APT_LISTS/archive_dists_noble_InRelease"
  : >"$T/calls"
  apt_refresh
  not_called "apt-get update"
  touch -t 202001010000 "$APT_LISTS/archive_dists_noble_InRelease"
  apt_refresh >/dev/null
  called "sudo apt-get update"
  touch "$APT_LISTS/archive_dists_noble_InRelease"
  : >"$T/calls"
  apt_refresh force >/dev/null
  called "sudo apt-get update"
)
# an upgrade that needs a restart says so, and restarts nothing
(
  load ubuntu
  REBOOT_FLAG=$T/reboot-required
  apt_upgrade >/dev/null
  called "apt-get upgrade -y"
  [[ ${#TODOS[@]} == 0 ]] || fail "no restart needed: no todo"
  touch "$REBOOT_FLAG"
  apt_upgrade >/dev/null
  [[ ${TODOS[*]} == *"restart the computer"* ]] || fail "a restart is needed: a todo"
  not_called "reboot"
)
# debian's names for bat and fd, under the names everything else uses
(
  load ubuntu
  fresh_home
  stub batcat
  stub fdfind
  PATH=$T/bin:/usr/bin:/bin
  debian_names
  eq "bat" "$T/bin/batcat" "$(readlink "$HOME/.local/bin/bat")"
  eq "fd" "$T/bin/fdfind" "$(readlink "$HOME/.local/bin/fd")"
  eq "again: nothing said" "" "$(debian_names)"
  rm -f "$T/bin/batcat" "$T/bin/fdfind" "$HOME/.local/bin/bat" "$HOME/.local/bin/fd"
  debian_names
  no "no batcat: no bat link" test -L "$HOME/.local/bin/bat"
)
# ghostty's terminal description, where the system doesn't know it
(
  load ubuntu
  stub infocmp 'exit 1'
  stub tic
  terminfo_install >/dev/null
  called "tic -x -o $HOME/.terminfo $REPO/ubuntu/xterm-ghostty.terminfo"
  stub infocmp 'exit 0'
  : >"$T/calls"
  terminfo_install
  not_called "tic"
)
ok "the terminfo source describes xterm-ghostty" grep -q '^xterm-ghostty|' "$REPO/ubuntu/xterm-ghostty.terminfo"

# --- tools: from apt when apt's is new enough, else from the project's own release ---

(
  load ubuntu
  ok "0.11.6-1 meets 0.11.0" version_ge 0.11.6-1 0.11.0
  no "0.9.5-6ubuntu2 doesn't meet 0.11.0" version_ge 0.9.5-6ubuntu2 0.11.0
  ok "an epoch is set aside" version_ge 1:2.53.0-1ubuntu1 2.40.0
  ok "a +ds suffix is set aside" version_ge 0.57.0+ds1-1 0.40.0
  no "0.44.1-1ubuntu0.3 doesn't meet 0.48.0" version_ge 0.44.1-1ubuntu0.3 0.48.0
  ok "equal meets" version_ge 0.48.0-1 0.48.0
  ok "0.10 is newer than 0.9" version_ge 0.10.0-1 0.9.9
  stub uname 'echo aarch64'
  eq "arm" arm64 "$(tool_arch)"
  stub uname 'echo x86_64'
  eq "intel" amd64 "$(tool_arch)"
  stub uname 'echo riscv64'
  eq "another" "" "$(tool_arch)"
)
# the table: six fields a line, each asset name anchored and a regex jq takes
(
  load ubuntu
  eq "seven tools" "nvim tree-sitter fzf starship atuin lazygit sesh" "$(list "$REPO/ubuntu/tools.txt" | awk '{ print $1 }' | paste -sd' ' -)"
  while read -r cmd pkg min repo arm amd rest; do
    [[ -n $amd && -z $rest ]] || fail "tools.txt: $cmd has six fields"
    [[ $repo == */* ]] || fail "tools.txt: $cmd names a github repo"
    for re in "$arm" "$amd"; do
      [[ $re == ^*$ ]] || fail "tools.txt: $cmd's asset name is anchored: $re"
      jq -n --arg re "$re" '"x" | test($re)' >/dev/null || fail "tools.txt: $cmd's asset name is a regex: $re"
    done
    [[ $pkg == - || $min =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "tools.txt: $cmd's minimum is a version"
  done < <(list "$REPO/ubuntu/tools.txt")
  eq "arm and intel names differ" 0 "$(list "$REPO/ubuntu/tools.txt" | awk '$5 == $6 { n++ } END { print n + 0 }')"
)

# release <tag> <asset name> <file>: github's answer for a latest release with that one asset, and a curl
# that gives it for an api address and the file for a download; gh isn't signed in
release() {
  jq -n --arg t "$1" --arg n "$2" --arg d "sha256:$(sha256sum "$3" | awk '{ print $1 }')" \
    '{ tag_name: $t, assets: [{ name: $n, browser_download_url: ("https://example.invalid/" + $n), digest: $d }] }' >"$T/release.json"
  cp "$3" "$T/asset"
  stub gh 'exit 1'
  stub curl 'out=""; url=""; while (($#)); do case $1 in -o) out=$2; shift ;; http*) url=$1 ;; esac; shift; done
if [[ $url == https://api.github.com/* ]]; then cat "$T/release.json"; else cp "$T/asset" "$out"; fi'
}
# nvim_tar <version>: a tar.gz shaped like neovim's, whose nvim prints that version
nvim_tar() {
  rm -rf "$T/build"
  mkdir -p "$T/build/nvim-linux-arm64/bin" "$T/build/nvim-linux-arm64/share/nvim"
  printf '#!/bin/sh\necho "NVIM %s"\n' "$1" >"$T/build/nvim-linux-arm64/bin/nvim"
  chmod +x "$T/build/nvim-linux-arm64/bin/nvim"
  tar -czf "$T/nvim.tar.gz" -C "$T/build" nvim-linux-arm64
}
# entries <dir>: everything in a folder, hidden files too, on one line
entries() { (cd "$1" && find . -mindepth 1 -maxdepth 1 | sed 's|^\./||' | sort | paste -sd' ' -); }
# one_tool <line>: tools_install over a table of that one line
one_tool() {
  printf '%s\n' "$1" >"$T/tools.txt"
  TOOLS=$T/tools.txt tools_install
}
NVIM='nvim neovim 0.11.0 neovim/neovim ^nvim-linux-arm64\.tar\.gz$ ^nvim-linux-x86_64\.tar\.gz$'

# apt's neovim is new enough: apt installs it, and nothing is downloaded
(
  load ubuntu
  fresh_home
  stub uname 'echo aarch64'
  stub apt-cache 'echo "  Candidate: 0.11.6-1"'
  stub dpkg-query 'exit 1'
  stub curl 'exit 1'
  one_tool "$NVIM" >/dev/null
  called "apt-get install -y --no-install-recommends neovim"
  not_called "curl"
  [[ ${#TODOS[@]} == 0 ]] || fail "apt's neovim: no todo"
)
# apt's is too old: the release, unpacked whole, its command linked, its tag kept; a second run is quiet
(
  load ubuntu
  fresh_home
  stub uname 'echo aarch64'
  stub apt-cache 'echo "  Candidate: 0.9.5-6ubuntu2"'
  nvim_tar 0.12.6
  release v0.12.6 nvim-linux-arm64.tar.gz "$T/nvim.tar.gz"
  one_tool "$NVIM" >/dev/null
  not_called "apt-get install"
  eq "runs" "NVIM 0.12.6" "$("$HOME/.local/bin/nvim")"
  [[ $(readlink -f "$HOME/.local/bin/nvim") == "$(readlink -f "$HOME/.local/opt/nvim")"/* ]] || fail "the link points into ~/.local/opt/nvim"
  ok "the rest of the release came too" test -d "$HOME/.local/opt/nvim/nvim-linux-arm64/share/nvim"
  eq "tag kept" v0.12.6 "$(cat "$HOME/.local/opt/nvim/.release")"
  [[ ${#TODOS[@]} == 0 ]] || fail "installed: no todo"
  : >"$T/calls"
  eq "again: nothing said" "" "$(one_tool "$NVIM")"
  no "again: nothing downloaded" grep -q 'example.invalid' "$T/calls"
  # a newer release replaces it
  nvim_tar 0.13.0
  release v0.13.0 nvim-linux-arm64.tar.gz "$T/nvim.tar.gz"
  one_tool "$NVIM" >/dev/null
  eq "updated" "NVIM 0.13.0" "$("$HOME/.local/bin/nvim")"
  eq "no leftovers beside it" "nvim" "$(entries "$HOME/.local/opt")"

  # ubuntu upgraded since: apt's is good now, so the release copy goes and apt's is what runs
  stub apt-cache 'echo "  Candidate: 0.11.6-1"'
  stub dpkg-query 'exit 1'
  : >"$T/calls"
  one_tool "$NVIM" >/dev/null
  called "apt-get install -y --no-install-recommends neovim"
  no "release copy gone" test -e "$HOME/.local/opt/nvim"
  no "its link gone" test -L "$HOME/.local/bin/nvim"
)
# a download that doesn't match github's checksum, or is cut short: what's there stays, and a todo says so
(
  load ubuntu
  fresh_home
  stub uname 'echo aarch64'
  stub apt-cache 'echo "  Candidate: 0.9.5-6ubuntu2"'
  nvim_tar 0.12.6
  release v0.12.6 nvim-linux-arm64.tar.gz "$T/nvim.tar.gz"
  one_tool "$NVIM" >/dev/null
  nvim_tar 0.13.0
  release v0.13.0 nvim-linux-arm64.tar.gz "$T/nvim.tar.gz"
  echo tampered >>"$T/asset"
  one_tool "$NVIM" >/dev/null 2>&1
  eq "a bad checksum: the old one still runs" "NVIM 0.12.6" "$("$HOME/.local/bin/nvim")"
  eq "a bad checksum: its tag stays" v0.12.6 "$(cat "$HOME/.local/opt/nvim/.release")"
  [[ ${TODOS[*]} == *"nvim didn't install"* ]] || fail "a bad checksum: a todo"
  eq "a bad checksum: nothing left beside it" "nvim" "$(entries "$HOME/.local/opt")"
)
(
  load ubuntu
  fresh_home
  stub uname 'echo aarch64'
  stub apt-cache 'echo "  Candidate: 0.9.5-6ubuntu2"'
  nvim_tar 0.12.6
  head -c 100 "$T/nvim.tar.gz" >"$T/cut.tar.gz"
  release v0.12.6 nvim-linux-arm64.tar.gz "$T/cut.tar.gz"
  # the checksum github has is the cut file's own, so only the unpacking can tell
  one_tool "$NVIM" >/dev/null 2>&1 || fail "a cut-short download doesn't stop the run"
  no "a cut-short download: nothing installed" test -e "$HOME/.local/bin/nvim"
  [[ ${TODOS[*]} == *"nvim didn't install"* ]] || fail "a cut-short download: a todo"
)
# github can't be reached: the run goes on, and every tool that needed it is named
(
  load ubuntu
  fresh_home
  stub uname 'echo aarch64'
  stub apt-cache 'echo "  Candidate: (none)"'
  stub gh 'exit 1'
  stub curl 'exit 22'
  tools_install >/dev/null 2>&1 || fail "no github: the run goes on"
  for cmd in nvim tree-sitter fzf starship atuin lazygit sesh; do
    [[ ${TODOS[*]} == *"$cmd didn't install"* ]] || fail "no github: $cmd is named"
  done
  no "no github: nothing half-installed" bash -c "ls -A '$HOME/.local/opt' 2>/dev/null | grep -q ."
)
# github can't be reached, and the tool is there from an earlier run: it stays, and isn't said to be missing
(
  load ubuntu
  fresh_home
  stub uname 'echo aarch64'
  stub apt-cache 'echo "  Candidate: 0.9.5-6ubuntu2"'
  nvim_tar 0.12.6
  release v0.12.6 nvim-linux-arm64.tar.gz "$T/nvim.tar.gz"
  one_tool "$NVIM" >/dev/null
  stub curl 'exit 22'
  out=$(one_tool "$NVIM" 2>&1) || fail "no github, tool there: the run goes on"
  [[ $out == *"couldn't check for a newer nvim"* ]] || fail "no github, tool there: says it couldn't check: $out"
  one_tool "$NVIM" >/dev/null 2>&1
  [[ ${#TODOS[@]} == 0 ]] || fail "no github, tool there: no todo, got: ${TODOS[*]}"
  eq "no github, tool there: it still runs" "NVIM 0.12.6" "$("$HOME/.local/bin/nvim")"
)
# an architecture the releases have no build for: nothing is downloaded, and each tool says so once
(
  load ubuntu
  fresh_home
  stub uname 'echo riscv64'
  stub apt-cache 'echo "  Candidate: (none)"'
  stub gh 'exit 1'
  stub curl 'exit 1'
  out=$(tools_install 2>&1)
  not_called "curl"
  eq "one warning a tool" 7 "$(grep -c 'no build for this machine' <<<"$out")"
)
# a single gzipped file, as tree-sitter ships
(
  load ubuntu
  fresh_home
  stub uname 'echo x86_64'
  stub apt-cache 'echo "  Candidate: 0.20.8-5"'
  printf '#!/bin/sh\necho tree-sitter 0.27.2\n' >"$T/ts"
  gzip -c "$T/ts" >"$T/ts.gz"
  release v0.27.2 tree-sitter-linux-x64.gz "$T/ts.gz"
  one_tool 'tree-sitter tree-sitter-cli 0.25.0 tree-sitter/tree-sitter ^tree-sitter-linux-arm64\.gz$ ^tree-sitter-linux-x64\.gz$' >/dev/null
  eq "a gzipped command runs" "tree-sitter 0.27.2" "$("$HOME/.local/bin/tree-sitter")"
)
# no apt package at all, as sesh has: always its release
(
  load ubuntu
  fresh_home
  stub uname 'echo aarch64'
  stub apt-cache 'exit 1'
  mkdir -p "$T/s" && printf '#!/bin/sh\necho sesh\n' >"$T/s/sesh" && chmod +x "$T/s/sesh" && tar -czf "$T/sesh.tar.gz" -C "$T/s" sesh
  release v2.34.0 sesh_Linux_arm64.tar.gz "$T/sesh.tar.gz"
  one_tool 'sesh - - joshmedeski/sesh ^sesh_Linux_arm64\.tar\.gz$ ^sesh_Linux_x86_64\.tar\.gz$' >/dev/null
  eq "sesh runs" sesh "$("$HOME/.local/bin/sesh")"
  not_called "apt-cache"
)

# neovim's parsers are waited for, as a run with no screen is over before neovim has fetched them by itself
(
  load ubuntu
  stub nvim
  neovim_parsers
  called "nvim --headless +luafile $REPO/shared/neovim-parsers.lua +qa"
)
(
  load ubuntu
  stub nvim 'echo "no network"; exit 1'
  out=$(neovim_parsers 2>&1) || fail "parsers that didn't install don't end the run"
  [[ $out == *"no network"* && $out == *"warning"* ]] || fail "parsers that didn't install are said: $out"
)

# neovim didn't install, as when github couldn't be asked for its release: its steps wait, the rest of
# install is done, and what's left is said at the end rather than lost to a command that isn't there
(
  load ubuntu
  for f in not_root keep_sudo system_install tools_install link_home shell_install system_update tools_update shell_update; do eval "$f() { :; }"; done
  for f in neovim_install neovim_parsers neovim_update; do eval "$f() { echo ran-$f; }"; done
  out=$(NEOVIM_CMD=no-such-nvim os_install) || fail "no neovim: install goes on"
  eq "no neovim: its steps wait" "" "$out"
  NEOVIM_CMD=no-such-nvim os_install
  [[ ${TODOS[*]} == *"Neovim"* ]] || fail "no neovim: a todo says so"
  out=$(NEOVIM_CMD=no-such-nvim os_update) || fail "no neovim: update goes on"
  eq "no neovim: update's steps wait too" "" "$out"
  eq "with neovim: all of them run" "ran-neovim_install ran-neovim_parsers" "$(NEOVIM_CMD=true os_install | paste -sd' ' -)"
)
# a release file github publishes no checksum for isn't installed, and isn't even fetched
(
  load ubuntu
  fresh_home
  stub uname 'echo aarch64'
  stub apt-cache 'echo "  Candidate: 0.9.5-6ubuntu2"'
  nvim_tar 0.12.6
  release v0.12.6 nvim-linux-arm64.tar.gz "$T/nvim.tar.gz"
  jq 'del(.assets[].digest)' "$T/release.json" >"$T/r" && mv "$T/r" "$T/release.json"
  out=$(one_tool "$NVIM" 2>&1) || fail "no checksum: the run goes on"
  [[ $out == *"no checksum"* ]] || fail "no checksum: says so: $out"
  no "no checksum: nothing installed" test -e "$HOME/.local/bin/nvim"
  no "no checksum: nothing fetched" grep -q 'example.invalid' "$T/calls"
)
