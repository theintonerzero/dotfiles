# tests/helpers.sh: what every test file starts with: a temp home, stubs ahead of the real commands, and
# assertions; nothing a test does reaches the machine it runs on
# shellcheck shell=bash
# shellcheck disable=SC2016 # a stub's body is expanded when the stub runs
set -Eeuo pipefail
trap 'echo "  failed near line $LINENO" >&2' ERR

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
T=$(mktemp -d)
T=$(cd "$T" && pwd -P)
trap 'rm -rf "$T"' EXIT
export REPO T HOME=$T/home APPS=$T/Applications GIT_CONFIG_NOSYSTEM=1
unset XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_RUNTIME_DIR DOT_OS DOT_RESTARTED
mkdir -p "$HOME" "$APPS" "$T/bin"
: >"$T/calls"
export PATH=$T/bin:$PATH

# stub <name> [body]: a command that notes "<name> <args>" in $T/calls, then runs the body, or else succeeds
stub() {
  {
    printf '#!/bin/bash\n'
    printf 'printf "%%s\\n" "%s $*" >>"$T/calls"\n' "$1"
    printf '%s\n' "${2:-exit 0}"
  } >"$T/bin/$1"
  chmod +x "$T/bin/$1"
}

# sudo is noted and nothing is run, so no test can change the system
stub sudo

# stub_download <text>: a curl that writes the text to the file after -o
stub_download() {
  printf '%s\n' "$1" >"$T/download"
  stub curl 'out=""; while (($#)); do [[ $1 == -o ]] && out=$2; shift; done; [[ -z $out ]] || cp "$T/download" "$out"'
}

# stub_defaults: a defaults that answers `read <domain> <key>`, with -currentHost before it or not, from
# the "<domain> <key> <value>" lines of $T/have, failing when there's none, and the dock's apps from $T/dock
stub_defaults() {
  : >>"$T/have"
  stub defaults 'a=("$@"); [[ ${a[0]} != -currentHost ]] || a=("${a[@]:1}")
[[ ${a[0]} == read ]] || exit 0
if [[ ${a[1]} == com.apple.dock && ${a[2]} == persistent-apps ]]; then cat "$T/dock" 2>/dev/null; exit 0; fi
while read -r d k v; do
  if [[ $d == "${a[1]}" && $k == "${a[2]}" ]]; then printf "%s\n" "$v"; exit 0; fi
done <"$T/have"
exit 1'
}

calls() { cat "$T/calls"; }
fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}
called() { grep -qF -- "$1" "$T/calls" || fail "expected a call with: $1"; }
not_called() { if grep -qF -- "$1" "$T/calls"; then fail "expected no call with: $1"; fi; }
eq() { [[ $2 == "$3" ]] || fail "$1: wanted [$2], got [$3]"; }
ok() {
  local label=$1
  shift
  "$@" || fail "$label"
}
no() {
  local label=$1
  shift
  if "$@"; then fail "$label"; fi
}

# lib: lib.sh, with the stubs back ahead of what it puts on PATH
lib() {
  # shellcheck source=../lib.sh
  source "$REPO/lib.sh"
  PATH=$T/bin:$PATH
}

# load <os>: lib.sh and that os's steps, as install.sh has them
load() {
  export DOT_OS=$1
  lib
  load_steps "$1"
  PATH=$T/bin:$PATH
}
