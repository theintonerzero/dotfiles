#!/usr/bin/env bash
# tests/container.sh [--arch <arch>] [--keep] [image]: a real install in an ubuntu container, as a fresh
# server would run it: a user with sudo, git, a copy of this working tree, then install twice, a login
# shell, neovim, update and uninstall. the image is ubuntu:24.04 unless you name another; --keep leaves
# the container for a look around. it needs podman and the network and takes minutes, so it isn't one of
# tests/run.sh's
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
arch="" keep=0 image=ubuntu:24.04
while (($#)); do
  case $1 in
    --arch)
      arch=$2
      shift 2
      ;;
    --keep)
      keep=1
      shift
      ;;
    *)
      image=$1
      shift
      ;;
  esac
done
command -v podman >/dev/null || {
  echo "this needs podman" >&2
  exit 2
}

name=dotfiles-test-$$
logs=$(mktemp -d)
stage="starting" log=""
tools="nvim starship atuin fzf lazygit sesh tree-sitter eza bat fd rg zoxide tmux delta"

finish() {
  local status=$?
  if ((status == 0)); then
    echo "PASS $image${arch:+ ($arch)}"
  else
    if [[ -s $log ]]; then tail -n 25 "$log" | plain >&2; fi
    echo "FAIL $image${arch:+ ($arch)}: $stage (the logs are in $logs)"
  fi
  if ((keep)); then echo "kept: podman exec -it $name su -l tester"; else podman rm -f "$name" >/dev/null 2>&1 || true; fi
  exit "$status"
}
trap finish EXIT

# begin <stage>: names what runs next, and the log its output goes to
begin() {
  stage=$1
  log=$logs/$(tr ' ' '-' <<<"$1").log
  echo "-- $1"
}
# plain: what was printed, without the colours
plain() { sed $'s/\033\\[[0-9;]*m//g'; }
# root <script>: as root in the container
root() { podman exec "$name" bash -euo pipefail -c "$1"; }
# user <script>: as the user, at home in a login session with bash, as a fresh server gives over ssh from
# ghostty
user() { podman exec -e TERM=xterm-ghostty "$name" su -l tester -s /bin/bash -c "$1"; }
# quiet_run: ends the run if the stage's log has a warning, but for the ones a copy with no upstream earns
quiet_run() {
  local warnings
  # and atuin's, which has no history to import on a machine nobody has used yet
  warnings=$(plain <"$log" | grep '^warning: ' | grep -v -e 'no upstream to pull from' -e "atuin couldn't import your history" || true)
  [[ -z $warnings ]] || wrong "it warned: $warnings"
}
# wrong <what>: ends the run at this stage
wrong() {
  echo "$1" >>"$log"
  exit 1
}

begin "the container"
# shellcheck disable=SC2086 # --arch and its value are two words
podman run -d --name "$name" ${arch:+--arch $arch} "$image" sleep infinity >"$log" 2>&1

begin "a user with sudo"
root 'export DEBIAN_FRONTEND=noninteractive
  apt-get update -q
  apt-get install -y -q --no-install-recommends sudo git ca-certificates
  useradd -m -s /bin/bash tester
  echo "tester ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/tester
  chmod 440 /etc/sudoers.d/tester' >"$log" 2>&1

begin "a copy of the working tree"
# what git tracks and what it would, as it is on disk; a repo of its own, so update finds no upstream
git -C "$repo" ls-files -co --exclude-standard -z |
  COPYFILE_DISABLE=1 tar -C "$repo" --no-xattrs --null -T - -cf - |
  podman exec -i "$name" bash -c 'mkdir -p /home/tester/dotfiles && tar -xf - -C /home/tester/dotfiles && chown -R tester: /home/tester/dotfiles' >"$log" 2>&1
user 'cd ~/dotfiles && git init -q && git add -A && git -c user.name=test -c user.email=test@example.invalid commit -qm "the working tree"' >>"$log" 2>&1

begin "install"
user 'dotfiles/install.sh' >"$log" 2>&1
quiet_run

begin "install again"
user 'dotfiles/install.sh' >"$log" 2>&1
# a second run has nothing to install: it says only that neovim's plugins are checked, and that it's done
again=$(plain <"$log" | grep '^==> ' | grep -v -e '^==> done$' -e "^==> installing neovim's plugins and language tools$" || true)
[[ -z $again ]] || wrong "the second install still did something: $again"
quiet_run

# login_shell <stage>: a login zsh, as over ssh: no complaint from it or its plugins, every tool found and
# at a version, and each from where this ubuntu should have it: its own release in ~/.local/opt where
# apt's is missing or too old, apt everywhere else
login_shell() {
  begin "$1"
  [[ $(root 'getent passwd tester | cut -d: -f7') == */zsh ]] || wrong "zsh isn't the login shell"
  podman exec -i "$name" tee /tmp/versions.zsh >/dev/null <<ZSH
for c in $tools; do
  p=\$(whence -p \$c) || { print -u2 "\$c: not found"; continue }
  case \$c in
    tmux) v=\$(\$p -V) ;;
    *) v=\$(\$p --version | head -n 1) ;;
  esac
  print "\$c \$p \$v"
done
whence -p dot >/dev/null || print -u2 "dot: not found"
ZSH
  # script gives zsh the terminal a login over ssh has; what zsh and its plugins complain of lands in a file
  user 'script -qec "zsh -lic \"source /tmp/versions.zsh\" 2>/tmp/zsh.err" /dev/null' | tr -d '\r' >"$log" 2>&1
  root 'cat /tmp/zsh.err' >"$logs/zsh.err"
  cat "$log"
  [[ ! -s $logs/zsh.err ]] || wrong "zsh complained: $(cat "$logs/zsh.err")"
  [[ $(grep -c . "$log") == $(wc -w <<<"$tools" | tr -d ' ') ]] || wrong "not every tool answered"
  nvim=$(awk '$1 == "nvim" { sub(/^v/, "", $4); print $4 }' "$log")
  [[ $(printf '%s\n' 0.11 "$nvim" | sort -V | head -n 1) == 0.11 ]] || wrong "neovim $nvim is older than 0.11"
  # root knows the terminal too, as sudo nano or sudo visudo over ssh from ghostty need it to
  user 'sudo infocmp xterm-ghostty >/dev/null 2>&1' || wrong "root doesn't know ghostty's terminal"
  # ubuntu 26.04 has all of them new enough but sesh, which it hasn't at all, and tree-sitter; 24.04 none
  local want="atuin fzf lazygit nvim sesh starship tree-sitter"
  # shellcheck disable=SC2016 # the container's shell expands it
  if [[ $(root '. /etc/os-release && echo "$VERSION_ID"') == 26.* ]]; then want="sesh tree-sitter"; fi
  [[ $(user 'ls ~/.local/opt' | paste -sd' ' -) == "$want" ]] || wrong "from their own releases: wanted [$want], got [$(user 'ls ~/.local/opt' | paste -sd' ' -)]"
}

login_shell "a login shell"

begin "neovim"
user 'nvim --headless +qa' >"$log" 2>&1
[[ ! -s $log ]] || wrong "neovim complained as it started"
user 'nvim --headless "+checkhealth" "+w! /tmp/health" +qa' >>"$log" 2>&1
root 'cat /tmp/health' >"$logs/health.txt"
# lazy's one error is luarocks, which no plugin here needs, and snacks' are its image and trash tools and
# the parts of it that wait for a screen; a desktop's report has the same. any other is a failure, the
# terminal's among them, which is how ghostty's terminal description is checked
errors=$(awk '/^=+$/ { head = 1; next } head { section = $1; sub(/:$/, "", section); head = 0 }
  /ERROR/ && section != "lazy" && section != "snacks" { print section ": " $0 }' "$logs/health.txt")
[[ -z $errors ]] || wrong "checkhealth has errors (all of it is in $logs/health.txt): $errors"
# that report has only what neovim loads as it starts; treesitter and mason are loaded and asked by name
user 'nvim --headless "+Lazy! load mason.nvim nvim-treesitter" "+checkhealth mason nvim-treesitter" "+w! /tmp/health-tools" +qa' >>"$log" 2>&1
root 'cat /tmp/health-tools' >"$logs/health-tools.txt"
for section in nvim-treesitter mason; do
  grep -q "^$section:" "$logs/health-tools.txt" || wrong "$section's health wasn't run"
done
# on neovim 0.11 treesitter's health says its parser folder "is not in runtimepath" when it is: it compares
# the folder with a / on the end against the path without one. so that line is set aside, and what it's
# about is checked for real instead: the folder is on the path, and a lua file opened here is highlighted
if grep -n 'ERROR' "$logs/health-tools.txt" | grep -v 'ERROR is not in runtimepath\.$' >>"$log"; then
  wrong "treesitter's or mason's health has errors (all of it is in $logs/health-tools.txt)"
fi
podman exec -i "$name" tee /tmp/highlight.lua >/dev/null <<'LUA'
vim.wait(1500)
local site = vim.fs.normalize(vim.fn.stdpath "data" .. "/site")
local on_path = false
for _, path in ipairs(vim.api.nvim_list_runtime_paths()) do
  if vim.fs.normalize(path) == site then on_path = true end
end
if not on_path then io.write "the parser folder isn't on the runtime path\n" end
if not vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] then io.write "a lua file isn't highlighted\n" end
LUA
user 'printf "local x = 1\n" >/tmp/sample.lua && nvim --headless /tmp/sample.lua "+luafile /tmp/highlight.lua" +qa' >"$logs/highlight.txt" 2>&1
[[ ! -s $logs/highlight.txt ]] || wrong "treesitter isn't working: $(cat "$logs/highlight.txt")"
user 'ls ~/.local/share/nvim/mason/bin' >"$logs/mason.txt" 2>&1
for tool in lua-language-server stylua shellcheck shfmt taplo marksman; do
  grep -qx "$tool" "$logs/mason.txt" || wrong "mason didn't install $tool"
done
user 'nvim --headless "+lua for _, l in ipairs({ \"lua\", \"bash\", \"json\", \"yaml\", \"toml\", \"markdown\" }) do if not pcall(vim.treesitter.language.add, l) or not vim.treesitter.language.add(l) then io.write(l .. \" \") end end" +qa' >"$logs/parsers.txt" 2>&1
[[ ! -s $logs/parsers.txt ]] || wrong "treesitter has no parser for: $(cat "$logs/parsers.txt")"

begin "update"
user 'dotfiles/update.sh' >"$log" 2>&1
grep -q 'no upstream' "$log" || wrong "update didn't say the copy has no upstream"
quiet_run
login_shell "a login shell after update"

begin "uninstall"
user 'dotfiles/uninstall.sh' >"$log" 2>&1
left=$(user 'find ~ -path ~/dotfiles -prune -o -type l -lname "*dotfiles/*" -print')
[[ -z $left ]] || wrong "links into the dotfiles are left: $left"
