# macos/bar.sh: the bar (sketchybar) running in place of apple's menu bar, and the wallpaper it was drawn
# against
# shellcheck shell=bash

BAR=${BAR:-sketchybar}
# what launchd knows the bar's service as: homebrew's name for it now, and the one it had before
BAR_SERVICES=(sh.brew.sketchybar homebrew.mxcl.sketchybar)
# pro black, which macos fetches the first time it's chosen, and plain black for a mac that hasn't yet
WALLPAPER=${WALLPAPER:-$HOME/Library/Application Support/com.apple.mobileAssetDesktop/Pro Black.heic}
WALLPAPER_PLAIN=${WALLPAPER_PLAIN:-/System/Library/Desktop Pictures/Solid Colors/Black.png}

# bar_install: the bar started, now and at each login, and only then apple's menu bar hidden, so there's
# never a mac with neither
bar_install() {
  if ! have "$BAR"; then
    todo "the bar isn't installed, so apple's menu bar stays; run dot install again"
    return 0
  fi
  if ! bar_start; then
    todo "the bar didn't start, so apple's menu bar stays; run dot install again"
    return 0
  fi
  menu_bar_hide true
  wallpaper_apply
}

# bar_update: a running bar reads its config again, as the pull may have changed it
bar_update() {
  bar_running || return 0
  "$BAR" --reload >/dev/null 2>&1 || true
}

# bar_uninstall: the bar stopped, and apple's menu bar back where it was
bar_uninstall() {
  if bar_running; then
    say "stopping the bar"
    brew services stop sketchybar </dev/null >/dev/null 2>&1 || warn "couldn't stop the bar: brew services stop sketchybar"
  fi
  menu_bar_hide false
}

# bar_running: whether launchd has the bar's service, which homebrew starts at each login
bar_running() {
  local service
  for service in "${BAR_SERVICES[@]}"; do
    if launchctl print "gui/$UID/$service" >/dev/null 2>&1; then return 0; fi
  done
  return 1
}

# bar_start: the service, started where launchd hasn't it; a bar that's running reads its config again
bar_start() {
  if bar_running; then
    "$BAR" --reload >/dev/null 2>&1 || true
    return 0
  fi
  say "starting the bar"
  quiet brew services start sketchybar
}

# menu_bar_hide <true|false>: apple's menu bar hidden until the pointer reaches the top of the screen, or
# always there; set through system events, as system settings does, so it takes effect at once
menu_bar_hide() {
  local have
  have=$(osascript -e 'tell application "System Events" to get autohide menu bar of dock preferences' 2>/dev/null </dev/null) || have=""
  [[ $have == "$1" ]] && return 0
  if [[ $1 == true ]]; then say "hiding apple's menu bar, which the bar stands in for"; else say "showing apple's menu bar again"; fi
  osascript -e "tell application \"System Events\" to set autohide menu bar of dock preferences to $1" >/dev/null </dev/null ||
    warn "couldn't change the menu bar; it's in System Settings > Menu Bar"
}

# wallpaper_apply: pro black on every desktop, where it isn't the wallpaper already; plain black on a mac
# that hasn't fetched pro black, with how to get it
wallpaper_apply() {
  local want=$WALLPAPER have
  if [[ ! -f $want ]]; then
    want=$WALLPAPER_PLAIN
    todo "choose Pro Black once in System Settings > Wallpaper, so macOS fetches it; until then the wallpaper is plain black"
  fi
  have=$(osascript -e 'tell application "System Events" to get picture of current desktop' 2>/dev/null </dev/null) || have=""
  [[ $have == "$want" ]] && return 0
  say "setting the wallpaper"
  osascript -e 'on run argv' -e 'tell application "System Events" to tell every desktop to set picture to (item 1 of argv)' \
    -e 'end run' "$want" >/dev/null </dev/null || warn "couldn't set the wallpaper"
}
