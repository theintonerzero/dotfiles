# fedora/apps.sh: flatpaks, the apps fedora doesn't package, the nerd font and firefox's paste setting
# shellcheck shell=bash

FIREFOX_PREFS=/usr/lib64/firefox/browser/defaults/preferences/dotfiles.js
FIREFOX_POLICIES=/etc/firefox/policies/policies.json

apps_install() {
  apps_flatpaks
  apps_spotify
  apps_gtk_css
  apps_releases
  font_install || todo "the nerd font didn't install; dot update tries again"
  firefox_prefs
  firefox_policies
  firefox_bookmarks
}

apps_update() {
  say "updating flatpaks"
  flatpak update --user -y --noninteractive || warn "flatpak couldn't update the flatpaks"
  apps_releases
  font_install || true
}

apps_uninstall() {
  if [[ -e $FIREFOX_PREFS ]]; then as_root rm -f "$FIREFOX_PREFS"; fi
  if [[ -e $FIREFOX_POLICIES ]]; then as_root rm -f "$FIREFOX_POLICIES"; fi
}

# apps_gtk_css: flatpak apps read the window-button css too, and the repo folder its links point into
apps_gtk_css() {
  local show
  show=$(flatpak override --user --show 2>/dev/null)
  [[ $show == *"$DOTFILES/home/gtk:ro"* && $show == *"xdg-config/gtk-4.0:ro"* ]] && return 0
  say "letting flatpak apps use the window buttons' css"
  flatpak override --user --filesystem=xdg-config/gtk-4.0:ro --filesystem=xdg-config/gtk-3.0:ro \
    --filesystem="$DOTFILES/home/gtk:ro"
}

# apps_spotify: spotify's flatpak on x11, not wayland, where it draws a blue title bar of its own; on
# x11, gnome draws it like every other window's
apps_spotify() {
  [[ $(flatpak override --user --show com.spotify.Client 2>/dev/null) == *"!wayland"* ]] && return 0
  say "letting gnome draw spotify's title bar"
  flatpak override --user --nosocket=wayland --socket=x11 com.spotify.Client
}

# the apps in flatpaks.txt, from flathub, in your user installation
apps_flatpaks() {
  local app
  local -a missing=()
  if ! grep -qx flathub <<<"$(flatpak remotes --user --columns=name 2>/dev/null)"; then
    say "adding flathub"
    flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  fi
  for app in $(list "$DOTFILES/fedora/flatpaks.txt"); do
    flatpak info --user "$app" >/dev/null 2>&1 || missing+=("$app")
  done
  ((${#missing[@]})) || return 0
  say "installing ${missing[*]} from flathub"
  flatpak install --user -y --noninteractive flathub "${missing[@]}"
}

# vesktop and artcraft launcher, from the rpms on their github releases
apps_releases() {
  rpm_release Vencord/Vesktop '^vesktop-.*\.x86_64\.rpm$' vesktop ||
    todo "Vesktop didn't install; dot update tries again"
  rpm_release storytold/craft-launcher '^artcraft-launcher-.*-linux-x86_64\.rpm$' artcraft-launcher ||
    todo "ArtCraft Launcher didn't install; dot update tries again"
}

# rpm_release <owner/repo> <asset regex> <package>: installs the latest release's rpm unless it's installed
rpm_release() {
  local repo=$1 re=$2 pkg=$3 tag want have="" url tmp
  tag=$(gh_tag "$repo") || tag=""
  if [[ -z $tag ]]; then
    warn "couldn't read $repo's latest release"
    return 1
  fi
  want=${tag#v}
  if rpm -q --quiet "$pkg"; then have=$(rpm -q --qf '%{VERSION}' "$pkg"); fi
  [[ $have == "$want" ]] && return 0
  url=$(gh_asset "$repo" "$re")
  if [[ -z $url ]]; then
    warn "$repo $tag has no file matching $re"
    return 1
  fi
  tmp=$(mktemp -d)
  say "installing $pkg $want"
  if ! fetch "$url" "$tmp/$pkg.rpm"; then
    warn "couldn't download $url"
    rm -rf "$tmp"
    return 1
  fi
  if ! as_root dnf install -y "$tmp/$pkg.rpm"; then
    warn "couldn't install $pkg"
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$tmp"
}

# font_install: jetbrains mono nerd font, the latest release, in ~/.local/share/fonts
font_install() {
  local dir=$HOME/.local/share/fonts/JetBrainsMonoNerdFont tag url tmp
  tag=$(gh_tag ryanoasis/nerd-fonts) || tag=""
  if [[ -z $tag ]]; then
    warn "couldn't read nerd-fonts' latest release"
    return 1
  fi
  if [[ -f $dir/.version && $(<"$dir/.version") == "$tag" ]]; then return 0; fi
  url=$(gh_asset ryanoasis/nerd-fonts '^JetBrainsMono\.tar\.xz$')
  tmp=$(mktemp -d)
  say "installing JetBrainsMono Nerd Font $tag"
  if [[ -n $url ]] && fetch "$url" "$tmp/font.tar.xz" && mkdir "$tmp/font" && tar -xJf "$tmp/font.tar.xz" -C "$tmp/font"; then
    rm -rf "$dir"
    mkdir -p "$(dirname "$dir")"
    mv "$tmp/font" "$dir"
    echo "$tag" >"$dir/.version"
    fc-cache -f "$dir" >/dev/null
    rm -rf "$tmp"
  else
    warn "couldn't download the nerd font"
    rm -rf "$tmp"
    return 1
  fi
}

# firefox_prefs: a default pref file that turns off middle-click paste in firefox
firefox_prefs() {
  local want='pref("middlemouse.paste", false);'
  [[ -d $(dirname "$FIREFOX_PREFS") ]] || return 0
  [[ -f $FIREFOX_PREFS && $(<"$FIREFOX_PREFS") == "$want" ]] && return 0
  say "turning off middle-click paste in firefox"
  printf '%s\n' "$want" | as_root tee "$FIREFOX_PREFS" >/dev/null
}

# firefox_policies: firefox-policies.json as firefox's policies: ublock origin, https-only mode, and no
# ads, telemetry or ai features; telemetry and studies stay off, the rest you can change in firefox
firefox_policies() {
  have firefox || return 0
  cmp -s "$DOTFILES/fedora/firefox-policies.json" "$FIREFOX_POLICIES" && return 0
  say "setting firefox's policies"
  as_root install -Dm644 "$DOTFILES/fedora/firefox-policies.json" "$FIREFOX_POLICIES"
  todo "restart Firefox for its new policies; about:policies lists them"
}

# firefox_bookmarks: fedora's bookmarks out of the profiles made before the policies said no to them, as
# install's github sign-in opens firefox first; yours stay, and each changed database keeps a .bak
firefox_bookmarks() {
  local tmp db out status=0
  local -a dbs=()
  have firefox || return 0
  for db in "$HOME"/.config/mozilla/firefox/*/places.sqlite "$HOME"/.mozilla/firefox/*/places.sqlite; do
    [[ -f $db ]] && dbs+=("$db")
  done
  ((${#dbs[@]})) || return 0
  tmp=$(mktemp)
  # omni.ja is a zip that unzip warns about but reads
  unzip -p /usr/lib64/firefox/browser/omni.ja chrome/browser/content/browser/default-bookmarks.html \
    >"$tmp" 2>/dev/null || true
  if [[ ! -s $tmp ]]; then
    warn "couldn't read firefox's default bookmarks, so fedora's stay"
    rm -f "$tmp"
    return 0
  fi
  out=$(python3 -I "$DOTFILES/fedora/firefox-bookmarks.py" "$tmp" "${dbs[@]}" 2>&1) || status=$?
  rm -f "$tmp"
  [[ -n $out ]] && say "$out"
  if ((status == 3)); then
    todo "close Firefox, then run dot install again to remove Fedora's bookmarks"
  elif ((status)); then
    warn "couldn't remove fedora's bookmarks"
  fi
}
