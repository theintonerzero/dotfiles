# shared/platform.sh: what differs between linux and macos for the shared steps: where apps are and keep
# their settings, and what their processes are called
# shellcheck shell=bash

# an update begun by older files still has their lib.sh in memory, which these steps have outgrown, so it
# starts again with the files it just pulled
if [[ ${DOT_LIB:-1} -lt 2 ]]; then
  if [[ -n ${DOT_RESTARTED:-} ]]; then
    printf 'error: %s\n' "the dotfiles' lib.sh is older than their steps: run dot install" >&2
    exit 1
  fi
  export DOT_RESTARTED=1
  exec "$0"
fi

# where macos keeps its apps
APPS=${APPS:-/Applications}

# running <name>...: true when a process by any of the names is running; apps go by another name on macos
running() {
  local name
  for name; do
    if pgrep -x "$name" >/dev/null; then return 0; fi
  done
  return 1
}

# app_dir <linux name> <macos name>: the folder an app keeps its settings in: ~/.config/<linux name>, or
# on macos ~/Library/Application Support/<macos name>
app_dir() {
  if [[ $(os_id) == macos ]]; then
    printf '%s\n' "$HOME/Library/Application Support/$2"
  else
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/$1"
  fi
}
