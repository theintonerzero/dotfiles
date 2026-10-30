# lib.sh: helpers for install.sh, update.sh, uninstall.sh and every step file
# shellcheck shell=bash

DOTFILES=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)
TODOS=()
# what the steps install is on PATH for the steps after them, in ~/.zshenv's order
export PATH=$HOME/.local/bin:${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims:${CARGO_HOME:-$HOME/.cargo}/bin:$PATH

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() {
  printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
  exit 1
}
have() { command -v "$1" >/dev/null 2>&1; }

# as_root <cmd...>: runs a command as root, through sudo unless we already are root
as_root() {
  if ((EUID == 0)); then "$@"; else sudo "$@"; fi
}

# keep_sudo: asks for the sudo password once and keeps it fresh until the script ends
keep_sudo() {
  ((EUID == 0)) && return 0
  sudo -v || die "the system steps need sudo"
  # its output goes nowhere, so a piped run ends when the script does
  (while kill -0 "$$" 2>/dev/null; do
    sudo -n true 2>/dev/null
    sleep 50
  done) >/dev/null 2>&1 &
}

# list <file>: the items of a list file: no comments, no blank lines, no padding
list() {
  sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"
}

# tty_ok: true when there is a terminal to ask questions on
tty_ok() { { true </dev/tty; } 2>/dev/null; }

# ask <var> <prompt> [default]: reads an answer from the terminal; without one, takes the default
ask() {
  local reply=""
  if tty_ok; then read -r -p "$2${3:+ [$3]}: " reply </dev/tty || reply=""; fi
  printf -v "$1" '%s' "${reply:-${3:-}}"
}

# quiet <cmd...>: runs a command without its chatter; when it fails, shows everything it printed
quiet() {
  local out status=0
  out=$("$@" 2>&1 </dev/null) || status=$?
  if ((status)); then printf '%s\n' "$out" >&2; fi
  return "$status"
}

# todo <msg>: a step only you can do, listed at the end of the run
todo() { TODOS+=("$*"); }
todo_print() {
  ((${#TODOS[@]})) || return 0
  printf '\n\033[1mLeft for you:\033[0m\n'
  printf '  - %s\n' "${TODOS[@]}"
}

# os_id: fedora, ubuntu, macos or unknown
os_id() {
  local id=""
  if [[ $(uname -s) == Darwin ]]; then
    echo macos
    return
  fi
  if [[ -r /etc/os-release ]]; then id=$(. /etc/os-release && echo "${ID:-}"); fi
  case $id in
    fedora | ubuntu) echo "$id" ;;
    *) echo unknown ;;
  esac
}

# gh_release <owner/repo>: the latest release, as json
gh_release() {
  if have gh && gh auth status >/dev/null 2>&1; then
    gh api "repos/$1/releases/latest"
  else
    curl -fsSL "https://api.github.com/repos/$1/releases/latest"
  fi
}

# gh_tag <owner/repo>: the latest release's tag
gh_tag() { gh_release "$1" | jq -r '.tag_name // empty'; }

# gh_asset <owner/repo> <regex>: the download url of the latest release's first matching asset
gh_asset() {
  gh_release "$1" | jq -r --arg re "$2" '[.assets[] | select(.name | test($re))][0].browser_download_url // empty'
}

# fetch <url> <dest>: downloads to dest.part and moves it into place only once it's complete
fetch() {
  rm -f "$2.part"
  if curl -fsSL --retry 2 -o "$2.part" "$1" && [[ -s $2.part ]]; then
    mv -f "$2.part" "$2"
  else
    rm -f "$2.part"
    return 1
  fi
}

# load_steps <os>: sources the shared steps and the os's own steps (they only define functions)
load_steps() {
  local f
  for f in "$DOTFILES"/shared/*.sh "$DOTFILES/$1"/*.sh; do
    if [[ -e $f ]]; then
      # shellcheck source=/dev/null
      source "$f"
    fi
  done
}

# packages: the stow packages in home/
packages() {
  local d
  for d in "$DOTFILES"/home/*/; do basename "$d"; done
}

# package_files <pkg>: every file a package links, relative to home
package_files() {
  (cd "$DOTFILES/home/$1" && find . \( -type f -o -type l \) -printf '%P\n')
}

# package_dirs <pkg>: every folder a package's files sit in, relative to home
package_dirs() {
  (cd "$DOTFILES/home/$1" && find . -mindepth 1 -type d -printf '%P\n')
}

# link_home: links every package into ~, moving anything in the way to <file>.bak first
link_home() {
  local pkg rel target bak
  local -a pkgs
  mapfile -t pkgs < <(packages)
  # a folder linked in from elsewhere, like another dotfiles setup, would have its files moved aside in
  # that other tree before stow refuses it, so stop before anything moves
  for pkg in "${pkgs[@]}"; do
    while IFS= read -r rel; do
      target=$HOME/$rel
      if [[ -L $target && $(readlink -f "$target") != "$DOTFILES"/* ]]; then
        die "$target is a link to $(readlink -f "$target"): move it aside, then run dot install again"
      fi
    done < <(package_dirs "$pkg")
  done
  for pkg in "${pkgs[@]}"; do
    while IFS= read -r rel; do
      target=$HOME/$rel
      if [[ -e $target || -L $target ]] && [[ $(readlink -f "$target") != "$(readlink -f "$DOTFILES/home/$pkg/$rel")" ]]; then
        # an earlier backup stays as it is; a newer one goes beside it
        bak=$target.bak
        if [[ -e $bak || -L $bak ]]; then bak=$target.bak.$(date +%Y%m%d%H%M%S); fi
        say "moving $target aside to $bak"
        mv "$target" "$bak"
      fi
    done < <(package_files "$pkg")
  done
  stow --no-folding --restow -d "$DOTFILES/home" -t "$HOME" "${pkgs[@]}"
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$DOTFILES/bin/dot" "$HOME/.local/bin/dot"
}

# pull_dotfiles: the repo's new commits, when it has an upstream to pull from
pull_dotfiles() {
  if ! git -C "$DOTFILES" rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
    warn "the dotfiles have no upstream to pull from, so they stay as they are"
    return 0
  fi
  say "pulling the dotfiles"
  git -C "$DOTFILES" pull --ff-only
}

# unlink_home: removes the links and puts the .bak files back
unlink_home() {
  local pkg rel target
  local -a pkgs
  mapfile -t pkgs < <(packages)
  stow -D -d "$DOTFILES/home" -t "$HOME" "${pkgs[@]}"
  for pkg in "${pkgs[@]}"; do
    while IFS= read -r rel; do
      target=$HOME/$rel
      if [[ -e $target.bak && ! -e $target && ! -L $target ]]; then mv "$target.bak" "$target"; fi
    done < <(package_files "$pkg")
  done
  if [[ -L $HOME/.local/bin/dot ]]; then rm -f "$HOME/.local/bin/dot"; fi
}
