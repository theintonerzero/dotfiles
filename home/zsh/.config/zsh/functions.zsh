# functions: mkcd, oh, ffs and localhost

# _open <path or address>: opens it in its desktop app, with xdg-open on linux and open on macos
_open() {
  if (( $+commands[xdg-open] )); then
    setsid -f xdg-open "$@" >/dev/null 2>&1
  else open "$@"
  fi
}

# mkcd <dir>: makes a folder and goes into it
mkcd() {
  (( $# == 1 )) || { print -u2 'usage: mkcd <dir>'; return 2; }
  mkdir -p -- $1 && builtin cd -- $1
}

# oh [path]: opens a path, the current folder by default, in its desktop app
oh() {
  _open ${1:-.}
}

# ffs <words>: searches duckduckgo for the words
ffs() {
  (( $# )) || { print -u2 'usage: ffs <words>'; return 2; }
  local query
  query=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote_plus(" ".join(sys.argv[1:])))' "$@")
  _open "https://duckduckgo.com/?q=$query"
}

# localhost [port]: opens http://localhost:<port>, 3000 by default
localhost() {
  _open "http://localhost:${1:-3000}"
}
