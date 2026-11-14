# macos/apps.sh: the apps homebrew has no cask for, firefox's policies, the default browser, podman's
# linux vm, and the environment of apps started from the dock
# shellcheck shell=bash

# firefox reads its policies from this settings domain, outside the app, so they outlast its updates and
# leave its signature whole
FIREFOX_POLICIES=${FIREFOX_POLICIES:-/Library/Preferences/org.mozilla.firefox}
GUI_ENV=dev.dotfiles.environment

apps_install() {
  apps_releases
  firefox_policies
  default_browser
  podman_machine
}

apps_update() {
  apps_releases
}

apps_uninstall() {
  local agent=$HOME/Library/LaunchAgents/$GUI_ENV.plist
  if defaults read "$FIREFOX_POLICIES" >/dev/null 2>&1; then as_root defaults delete "$FIREFOX_POLICIES" || true; fi
  if [[ -f $agent ]]; then
    launchctl bootout "gui/$UID/$GUI_ENV" 2>/dev/null || true
    rm -f "$agent"
  fi
}

# podman_machine: fedora's podman runs containers on its own kernel; on macos it needs a linux vm, made
# once here, and started when you want it with podman machine start
podman_machine() {
  have podman || return 0
  [[ -z $(podman machine list -q 2>/dev/null </dev/null) ]] || return 0
  say "making podman's linux vm"
  quiet podman machine init || todo "podman's linux vm wasn't made: run podman machine init"
}

# artcraft launcher, from the dmg on its github releases
apps_releases() {
  dmg_release storytold/craft-launcher '^artcraft-launcher-.*-macos-universal\.dmg$' "ArtCraft Launcher" ||
    todo "ArtCraft Launcher didn't install; dot update tries again"
}

# dmg_release <owner/repo> <asset regex> <app name>: the app in the latest release's dmg, in /Applications,
# unless the one there is that release already
dmg_release() {
  local repo=$1 re=$2 app=$APPS/$3.app tag want have="" url tmp found status=0
  tag=$(gh_tag "$repo") || tag=""
  if [[ -z $tag ]]; then
    warn "couldn't read $repo's latest release"
    return 1
  fi
  want=${tag#v}
  if [[ -f $app/Contents/Info.plist ]]; then
    have=$(plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist" 2>/dev/null) || have=""
  fi
  [[ $have == "$want" ]] && return 0
  url=$(gh_asset "$repo" "$re")
  if [[ -z $url ]]; then
    warn "$repo $tag has no file matching $re"
    return 1
  fi
  tmp=$(mktemp -d)
  say "installing $3 $want"
  if ! fetch "$url" "$tmp/app.dmg"; then
    warn "couldn't download $url"
    rm -rf "$tmp"
    return 1
  fi
  if ! hdiutil attach -nobrowse -readonly -mountpoint "$tmp/mount" "$tmp/app.dmg" >/dev/null; then
    warn "couldn't open $3's dmg"
    rm -rf "$tmp"
    return 1
  fi
  found=$(find "$tmp/mount" -maxdepth 1 -name '*.app' | head -n 1)
  if [[ -z $found ]]; then
    warn "$3's dmg has no app in it"
    status=1
  elif [[ ${found##*/} != "$3.app" ]]; then
    # the version is read from the app by this name, so another name would be installed on every run
    warn "$3's dmg holds ${found##*/}: give macos/apps.sh that name"
    status=1
  else
    # the new one is whole before the old one goes
    rm -rf "$app.new"
    if cp -R "$found" "$app.new"; then
      rm -rf "$app"
      mv "$app.new" "$app"
    else
      rm -rf "$app.new"
      status=1
    fi
  fi
  hdiutil detach "$tmp/mount" >/dev/null 2>&1 || true
  rm -rf "$tmp"
  return "$status"
}

# firefox_policies_want: shared/firefox-policies.json as the settings domain takes it: the policies at
# the top, and the switch that has firefox read them
firefox_policies_want() {
  jq -S '.policies + {EnterprisePoliciesEnabled: true}' "$DOTFILES/shared/firefox-policies.json"
}

# firefox_policies: the same policies fedora sets: ublock origin, https-only mode, and no ads, telemetry
# or ai features
firefox_policies() {
  local want have tmp
  [[ -d $APPS/Firefox.app ]] || return 0
  if ! want=$(firefox_policies_want); then
    warn "shared/firefox-policies.json isn't valid json, so firefox's policies stay as they are"
    return 0
  fi
  have=$(defaults export "$FIREFOX_POLICIES" - 2>/dev/null | plutil -convert json -o - - 2>/dev/null | jq -S . 2>/dev/null) || have=""
  [[ $have == "$want" ]] && return 0
  say "setting firefox's policies"
  tmp=$(mktemp -d)
  printf '%s\n' "$want" >"$tmp/policies.json"
  if plutil -convert xml1 -o "$tmp/policies.plist" "$tmp/policies.json" &&
    as_root defaults import "$FIREFOX_POLICIES" "$tmp/policies.plist"; then
    todo "restart Firefox for its new policies; about:policies lists them"
  else
    warn "couldn't set firefox's policies"
  fi
  rm -rf "$tmp"
}

# default_browser: firefox, as on fedora; macos asks you to confirm, which nothing can do for you, so
# it's asked only while another browser is the default
default_browser() {
  local handler
  [[ -d $APPS/Firefox.app ]] || return 0
  have defaultbrowser || return 0
  handler=$(defaults read com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers 2>/dev/null |
    awk '/LSHandlerRoleAll/ { role = $3 } /LSHandlerURLScheme = https;/ { print role; exit }') || handler=""
  [[ $handler == *org.mozilla.firefox* ]] && return 0
  say "making firefox the default browser"
  defaultbrowser firefox >/dev/null 2>&1 || true
  todo "confirm Firefox as the default browser in the dialog macOS shows"
}

# gui_env: apps started from the dock or finder find the same tools as the shell, and unity's cli sends
# nothing home from them either: at login a launch agent hands them the PATH and unity's switches that
# ~/.zshenv sets, which every zsh reads. it's a file written here, not a link, as launchd wants its own
gui_env() {
  local dir=$HOME/Library/LaunchAgents file want
  file=$dir/$GUI_ENV.plist
  want=$(cat <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>dev.dotfiles.environment</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-c</string>
    <string>launchctl setenv PATH "$PATH"; for v in UNITY_NO_CLI_INVOKED_TELEMETRY UNITY_NO_CRASH_REPORT UNITY_NO_AGENT_HINTS UNITY_NO_UPDATE_CHECK; do launchctl setenv $v "${(P)v}"; done</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
PLIST
  )
  [[ -f $file && ! -L $file && $(<"$file") == "$want" ]] && return 0
  say "giving apps started from the dock the shell's path"
  mkdir -p "$dir"
  rm -f "$file"
  printf '%s\n' "$want" >"$file"
  launchctl bootout "gui/$UID/$GUI_ENV" 2>/dev/null || true
  launchctl bootstrap "gui/$UID" "$file" || warn "couldn't start the launch agent; it starts when you next log in"
}
