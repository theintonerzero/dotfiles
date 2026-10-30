# functions: mkcd, oh, ffs and localhost

# mkcd <dir>: makes a folder and goes into it
mkcd() {
  (( $# == 1 )) || { print -u2 'usage: mkcd <dir>'; return 2; }
  mkdir -p -- $1 && builtin cd -- $1
}

# oh [path]: opens a path, the current folder by default, in its desktop app
oh() {
  setsid -f xdg-open ${1:-.} >/dev/null 2>&1
}

# ffs <words>: searches duckduckgo for the words
ffs() {
  (( $# )) || { print -u2 'usage: ffs <words>'; return 2; }
  local query
  query=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote_plus(" ".join(sys.argv[1:])))' "$@")
  setsid -f xdg-open "https://duckduckgo.com/?q=$query" >/dev/null 2>&1
}

# localhost [port]: opens http://localhost:<port>, 3000 by default
localhost() {
  setsid -f xdg-open "http://localhost:${1:-3000}" >/dev/null 2>&1
}
