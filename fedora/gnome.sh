# fedora/gnome.sh: gnome's settings, extensions, dock, variable refresh rate and power mode
# shellcheck shell=bash

# the extensions installed from extensions.gnome.org, which has newer builds than fedora: blur my shell
# rounds the corners of live blur from v76 on
EGO_EXTENSIONS=(CoverflowAltTab@palatis.blogspot.com blur-my-shell@aunetx)

gnome_install() {
  if [[ -z ${DBUS_SESSION_BUS_ADDRESS:-} ]] || ! have gsettings; then
    todo "gnome's settings need the desktop: run dot install again from a terminal on it"
    return 0
  fi
  local uuid
  for uuid in "${EGO_EXTENSIONS[@]}"; do
    ego_install "$uuid" || todo "$uuid didn't install; dot update tries again"
  done
  gnome_blur_pipeline
  gnome_settings
  gnome_extensions
  gnome_shortcuts
  gnome_vrr
  gnome_power
}

# settings stay as you left them; only the extensions from extensions.gnome.org are updated
gnome_update() {
  [[ -n ${DBUS_SESSION_BUS_ADDRESS:-} ]] || return 0
  local uuid
  for uuid in "${EGO_EXTENSIONS[@]}"; do ego_install "$uuid" || true; done
}

# every line of gsettings.txt, set where it differs; a schema gnome doesn't know yet waits for a re-login
gnome_settings() {
  local schema key value dir
  local -a gs
  while read -r schema key value; do
    # an extension from extensions.gnome.org keeps its schema in its own folder
    gs=(gsettings)
    if ! grep -qxF "$schema" <<<"$(gsettings list-schemas)"; then
      for dir in "$HOME"/.local/share/gnome-shell/extensions/*/schemas; do
        if grep -qxF "$schema" <<<"$(gsettings --schemadir "$dir" list-schemas 2>/dev/null)"; then
          gs=(gsettings --schemadir "$dir")
          break
        fi
      done
      if [[ ${#gs[@]} == 1 ]]; then
        warn "gnome doesn't know $schema yet, so its $key waits"
        todo "log out and back in, then run dot install again to set $schema $key"
        continue
      fi
    fi
    [[ $("${gs[@]}" get "$schema" "$key") == "$value" ]] && continue
    say "setting $schema $key"
    "${gs[@]}" set "$schema" "$key" "$value"
  done < <(list "$DOTFILES/fedora/gsettings.txt")
}

# the extensions in extensions.txt join the ones already on; a new one starts at the next login
gnome_extensions() {
  local current uuid have list=""
  local -a on=()
  local changed=0
  current=$(gsettings get org.gnome.shell enabled-extensions)
  current=${current#@as }
  mapfile -t on < <(tr -d "[]' " <<<"$current" | tr , '\n' | sed '/^$/d')
  for uuid in $(list "$DOTFILES/fedora/extensions.txt"); do
    have=0
    for current in "${on[@]}"; do [[ $current == "$uuid" ]] && have=1; done
    if ((!have)); then
      on+=("$uuid")
      changed=1
    fi
  done
  if ((changed)); then
    for uuid in "${on[@]}"; do list+="${list:+, }'$uuid'"; done
    say "turning on gnome extensions"
    gsettings set org.gnome.shell enabled-extensions "[$list]"
  fi
  if [[ $(gsettings get org.gnome.shell disable-user-extensions) != false ]]; then
    gsettings set org.gnome.shell disable-user-extensions false
  fi
}

# gnome_shortcuts: the keyboard shortcuts in shortcuts.txt, as gnome custom shortcuts beside your own
gnome_shortcuts() {
  local schema=org.gnome.settings-daemon.plugins.media-keys
  local base=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings
  local name keys command path paths key value
  paths=$(gsettings get $schema custom-keybindings)
  while IFS='|' read -r name keys command; do
    path=${name,,}
    path=$base/dotfiles-${path// /-}/
    if [[ $paths != *"'$path'"* ]]; then
      say "adding the $name shortcut, $keys"
      if [[ $paths == *"[]"* ]]; then paths="['$path']"; else paths="${paths%]}, '$path']"; fi
      gsettings set $schema custom-keybindings "$paths"
    fi
    for key in name binding command; do
      case $key in name) value=$name ;; binding) value=$keys ;; command) value=$command ;; esac
      [[ $(gsettings get "$schema.custom-keybinding:$path" $key) == "'$value'" ]] ||
        gsettings set "$schema.custom-keybinding:$path" $key "'$value'"
    done
  done < <(list "$DOTFILES/fedora/shortcuts.txt")
}

# gnome_blur_pipeline: blur my shell's "Apps" pipeline, twice the default blur, for app windows; added
# once, beside the pipelines blur my shell keeps for its other parts
gnome_blur_pipeline() {
  local dir=$HOME/.local/share/gnome-shell/extensions/blur-my-shell@aunetx/schemas
  local key=org.gnome.shell.extensions.blur-my-shell current apps
  [[ -d $dir ]] || return 0
  current=$(gsettings --schemadir "$dir" get $key pipelines) || return 0
  [[ $current == *"'pipeline_apps'"* ]] && return 0
  apps="'pipeline_apps': {'name': <'Apps'>, 'effects': <[<{'type': <'dual_kawase_blur'>, 'id': <'effect_apps_blur'>, 'params': <{'unscaled_radius': <60>, 'brightness': <0.6>}>}>]>}"
  current=${current#@a\{sa\{sv\}\} }
  say "adding a stronger blur for app windows"
  if [[ $current == "{}" ]]; then
    gsettings --schemadir "$dir" set $key pipelines "{$apps}"
  else
    gsettings --schemadir "$dir" set $key pipelines "${current%\}}, $apps}"
  fi
}

# ego_install <uuid>: the newest build of an extension for this gnome, from extensions.gnome.org
ego_install() {
  local uuid=$1 shell info version url have dir tmp
  shell=$(gnome-shell --version)
  shell=${shell//[^0-9.]/}
  shell=${shell%%.*}
  if ! info=$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=$uuid&shell_version=$shell"); then
    warn "couldn't ask extensions.gnome.org about $uuid"
    return 1
  fi
  version=$(jq -r '.version // empty' <<<"$info")
  url=$(jq -r '.download_url // empty' <<<"$info")
  if [[ -z $url ]]; then
    warn "$uuid has no build for GNOME $shell yet"
    return 1
  fi
  dir=$HOME/.local/share/gnome-shell/extensions/$uuid
  have=$(jq -r '.version // empty' "$dir/metadata.json" 2>/dev/null || true)
  [[ $have == "$version" ]] && return 0
  tmp=$(mktemp -d)
  say "installing $uuid $version"
  if ! fetch "https://extensions.gnome.org$url" "$tmp/extension.zip"; then
    warn "couldn't download $uuid"
    rm -rf "$tmp"
    return 1
  fi
  if ! gnome-extensions install --force "$tmp/extension.zip"; then
    warn "couldn't install $uuid"
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$tmp"
}

# variable refresh rate on every monitor that offers it
gnome_vrr() {
  local out
  if out=$(python3 -I "$DOTFILES/fedora/vrr.py" 2>&1); then
    [[ $out == "vrr already on" ]] || say "$out"
  else
    warn "couldn't turn on variable refresh rate: $out"
  fi
}

# power_profiles <Get|Set> <property> [value]: reads or sets a property of gnome's power profiles service
power_profiles() {
  gdbus call --system --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles \
    --method "org.freedesktop.DBus.Properties.$1" net.hadess.PowerProfiles "${@:2}"
}

# the performance power mode, where the machine has one; it stays across reboots
gnome_power() {
  local profiles
  profiles=$(power_profiles Get Profiles 2>/dev/null) || return 0
  [[ $profiles == *"'performance'"* ]] || return 0
  [[ $(power_profiles Get ActiveProfile) == *"'performance'"* ]] && return 0
  say "setting the power mode to performance"
  power_profiles Set ActiveProfile "<'performance'>" >/dev/null
}
