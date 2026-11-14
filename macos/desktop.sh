# macos/desktop.sh: macos's settings from defaults.txt, the dock's apps, the power settings, and the
# folders the settings count on
# shellcheck shell=bash

desktop_install() {
  desktop_folders
  defaults_apply
  dock_apply
  power_apply
}

# desktop_folders: the folder screenshots go in, and ~/Library shown in finder
desktop_folders() {
  mkdir -p "$HOME/Pictures/Screenshots"
  if [[ $(stat -f %Sf "$HOME/Library" 2>/dev/null) == *hidden* ]]; then
    say "showing ~/Library in finder"
    chflags nohidden "$HOME/Library" || warn "couldn't show ~/Library"
  fi
}

# defaults_same <type> <have> <want>: whether a setting, as `defaults read` prints it, is what the list
# asks for; macos keeps some whole numbers as floats, and prints a bool as 1 or 0
defaults_same() {
  local number='^-?[0-9]+(\.[0-9]+)?$'
  case $1 in
    bool)
      case $3 in true | 1) [[ $2 == 1 ]] ;; *) [[ $2 == 0 ]] ;; esac
      ;;
    int | float)
      [[ $2 =~ $number && $3 =~ $number ]] || return 1
      awk -v a="$2" -v b="$3" 'BEGIN { exit !(a + 0 == b + 0) }'
      ;;
    *) [[ $2 == "$3" ]] ;;
  esac
}

# defaults_apply [list]: every line of defaults.txt, set where it differs; then finder, the dock and the
# menu bar restarted where a setting of theirs changed, and the rest waits for you to log out
defaults_apply() {
  local file=${1:-$DOTFILES/macos/defaults.txt} domain key type value have set
  local finder=0 dock=0 ui=0 logout=0
  local -a host
  while read -r domain key type value; do
    host=()
    if [[ $domain == -currentHost ]]; then
      host=(-currentHost)
      read -r domain key type value <<<"$key $type $value"
    fi
    value=${value/#\~/$HOME}
    set=1
    have=$(defaults "${host[@]}" read "$domain" "$key" 2>/dev/null </dev/null) || set=0
    if [[ $type == delete ]]; then
      ((set)) || continue
      say "unsetting $domain $key"
      if ! defaults "${host[@]}" delete "$domain" "$key" </dev/null; then
        warn "couldn't unset $domain $key"
        continue
      fi
    else
      if ((set)) && defaults_same "$type" "$have" "$value"; then continue; fi
      say "setting $domain $key"
      if ! defaults "${host[@]}" write "$domain" "$key" "-$type" "$value" </dev/null; then
        warn "couldn't set $domain $key"
        continue
      fi
    fi
    case $domain in
      com.apple.finder | com.apple.desktopservices) finder=1 ;;
      com.apple.dock) dock=1 ;;
      com.apple.screencapture) ui=1 ;;
      *) logout=1 ;;
    esac
  done < <(list "$file")
  if ((finder)); then killall Finder >/dev/null 2>&1 || true; fi
  if ((dock)); then killall Dock >/dev/null 2>&1 || true; fi
  if ((ui)); then killall SystemUIServer >/dev/null 2>&1 || true; fi
  if ((logout)); then todo "log out and back in, for the keyboard, mouse and appearance settings"; fi
}

# dock_url <name or path>: an app as the dock names it: a file url, with a / after it
dock_url() {
  local path=$1
  [[ $path == /* ]] || path=$APPS/$path.app
  printf 'file://%s/\n' "${path// /%20}"
}

# dock_apply: the apps in dock.txt that are installed, as the dock's apps, in the list's order, when
# they aren't already; the dock spells an app's name as the disk does, so the two are compared without
# regard to case
dock_apply() {
  local name path url want="" have
  local -a entries=()
  while IFS= read -r name; do
    path=$name
    [[ $path == /* ]] || path=$APPS/$name.app
    [[ -d $path ]] || continue
    url=$(dock_url "$name")
    want+=${want:+$'\n'}$url
    entries+=("<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$url</string><key>_CFURLStringType</key><integer>15</integer></dict></dict><key>tile-type</key><string>file-tile</string></dict>")
  done < <(list "$DOTFILES/macos/dock.txt")
  ((${#entries[@]})) || return 0
  have=$(defaults read com.apple.dock persistent-apps 2>/dev/null | sed -n 's/.*"_CFURLString" = "\(.*\)";/\1/p')
  [[ ${have,,} == "${want,,}" ]] && return 0
  say "setting the dock's apps"
  if defaults write com.apple.dock persistent-apps -array "${entries[@]}"; then
    killall Dock >/dev/null 2>&1 || true
  else
    warn "couldn't set the dock's apps"
  fi
}

# power_apply: each line of power.txt that differs from what pmset has; high power mode only on the macs
# that have one
power_apply() {
  local source setting value flag section have custom caps
  custom=$(pmset -g custom 2>/dev/null) || return 0
  caps=$(pmset -g cap 2>/dev/null) || caps=""
  while read -r source setting value; do
    case $source in
      charger) flag=-c section="AC Power:" ;;
      battery) flag=-b section="Battery Power:" ;;
      *) continue ;;
    esac
    if [[ $setting == powermode && $value == 2 && $caps != *highpowermode* ]]; then continue; fi
    have=$(awk -v s="$section" -v k="$setting" '
      $0 == s { on = 1; next } /^[A-Za-z].*:$/ { on = 0 } on && $1 == k { print $2; exit }' <<<"$custom")
    [[ $have == "$value" ]] && continue
    say "setting $setting to $value on the $source"
    as_root pmset "$flag" "$setting" "$value" </dev/null || warn "couldn't set $setting on the $source"
  done < <(list "$DOTFILES/macos/power.txt")
}
