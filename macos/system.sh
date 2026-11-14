# macos/system.sh: homebrew's formulae and casks, app store apps and xcode, and apple's apps removed
# shellcheck shell=bash

# garageband's sound library and instruments, which outlast the app
GARAGEBAND_FILES=("/Library/Application Support/GarageBand" "/Library/Application Support/Logic" "/Library/Audio/Apple Loops")

# system_first: what the questions and the linking run on, before anything is asked
system_first() {
  brew_install formula gh jq stow
}

system_install() {
  say "checking homebrew's formulae and casks"
  system_formulae
  system_casks
  system_appstore
  xcode_setup
  system_removals
}

system_update() {
  say "updating homebrew's formulae and casks"
  brew update || warn "homebrew couldn't update itself"
  brew upgrade || warn "homebrew couldn't upgrade everything"
  if have mas; then
    say "updating the app store's apps"
    mas upgrade </dev/null || warn "the app store's apps didn't update"
  fi
}

# brew_missing <formula|cask> <name>...: the names homebrew hasn't installed
brew_missing() {
  local kind=$1 installed name
  shift
  installed=$(brew list "--$kind" -1 2>/dev/null) || installed=""
  for name; do
    grep -qxF "$name" <<<"$installed" || echo "$name"
  done
}

# brew_install <formula|cask> <name>...: installs each one that's missing, one at a time, so one that
# fails is named at the end and the rest still go in
brew_install() {
  local kind=$1 name
  local -a flag=() missing
  shift
  if [[ $kind == cask ]]; then flag=(--cask); fi
  mapfile -t missing < <(brew_missing "$kind" "$@")
  for name in "${missing[@]}"; do
    say "installing $name"
    brew install "${flag[@]}" "$name" </dev/null || todo "$name didn't install; run dot install again"
  done
}

# the formulae in formulae.txt that aren't installed yet
system_formulae() {
  local -a names
  mapfile -t names < <(list "$DOTFILES/macos/formulae.txt")
  brew_install formula "${names[@]}"
}

# the casks in casks.txt that aren't installed yet
system_casks() {
  local -a names
  mapfile -t names < <(list "$DOTFILES/macos/casks.txt")
  brew_install cask "${names[@]}"
}

# the apps in appstore.txt that aren't installed yet; the app store installs only for someone signed in
# to it, which only you can do
system_appstore() {
  local id name installed
  have mas || return 0
  installed=$(mas list 2>/dev/null </dev/null) || installed=""
  while read -r id name; do
    # mas lines its ids up on the right, so a shorter one has spaces before it
    grep -qE "^[[:space:]]*${id}[[:space:]]" <<<"$installed" && continue
    say "installing $name from the app store"
    mas install "$id" </dev/null || todo "sign in to the App Store, then run dot install again for $name"
  done < <(list "$DOTFILES/macos/appstore.txt")
}

# xcode_setup: once xcode is there, the developer tools pointed at it, its licence accepted and its
# first-launch setup run, so it builds without being opened first
xcode_setup() {
  local xcode=$APPS/Xcode.app
  [[ -d $xcode ]] || return 0
  if [[ $(xcode-select -p 2>/dev/null) != "$xcode"/* ]]; then
    say "pointing the developer tools at xcode"
    as_root xcode-select -s "$xcode/Contents/Developer" || warn "couldn't point the developer tools at xcode"
  fi
  if ! xcodebuild -license check >/dev/null 2>&1; then
    say "accepting xcode's licence"
    as_root xcodebuild -license accept || warn "couldn't accept xcode's licence"
  fi
  if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
    say "finishing xcode's first launch"
    as_root xcodebuild -runFirstLaunch || warn "couldn't finish xcode's first launch"
  fi
}

# the apps in remove.txt that are installed; garageband's sound library goes with it, unless logic pro
# or mainstage, which share it, is there. an app macos won't let the terminal remove is left for you
system_removals() {
  local name app path
  while read -r name; do
    app=$APPS/$name.app
    [[ -e $app ]] || continue
    say "removing $name"
    as_root rm -rf "$app" || true
    if [[ -e $app ]]; then todo "remove $name yourself: macOS wouldn't let the terminal"; fi
    [[ $name == GarageBand ]] || continue
    if [[ -e "$APPS/Logic Pro.app" || -e $APPS/MainStage.app ]]; then continue; fi
    for path in "${GARAGEBAND_FILES[@]}"; do
      if [[ -e $path ]]; then as_root rm -rf "$path" || true; fi
    done
  done < <(list "$DOTFILES/macos/remove.txt")
}
