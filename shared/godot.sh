# shared/godot.sh: godot opens scripts in neovim, through godot-nvim, in every editor settings file it has
# shellcheck shell=bash

godot_install() {
  godot_formatter
  godot_settings
}

godot_update() {
  godot_formatter
}

# godot_formatter: gdscript-formatter's newest release in ~/.local/bin, which neovim runs on save
godot_formatter() {
  local bin=$HOME/.local/bin/gdscript-formatter tag url tmp file have=""
  tag=$(gh_tag GDQuest/GDScript-formatter) || tag=""
  [[ -n $tag ]] || { warn "couldn't look up gdscript-formatter's newest release"; return 0; }
  if [[ -x $bin ]]; then have=$("$bin" --version 2>/dev/null) || have=""; fi
  [[ -n $have && $have == *"${tag#v}"* ]] && return 0
  url=$(gh_asset GDQuest/GDScript-formatter '^gdscript-formatter-.*-linux-x86_64\.zip$') || url=""
  tmp=$(mktemp -d)
  say "installing gdscript-formatter $tag"
  if [[ -n $url ]] && fetch "$url" "$tmp/formatter.zip" && unzip -q "$tmp/formatter.zip" -d "$tmp/zip"; then
    file=$(find "$tmp/zip" -type f -name 'gdscript-formatter*' | head -n 1)
    if [[ -n $file ]]; then
      mkdir -p "$(dirname "$bin")"
      install -m 755 "$file" "$bin"
    else
      warn "gdscript-formatter's zip has no gdscript-formatter in it"
    fi
  else
    warn "couldn't download gdscript-formatter"
  fi
  rm -rf "$tmp"
}

# godot_settings: godot's external editor set to godot-nvim, while godot is closed
godot_settings() {
  local dir=${XDG_CONFIG_HOME:-$HOME/.config}/godot files f version
  have godot || return 0
  if pgrep -x godot >/dev/null; then
    todo "close Godot and run dot install again, so Godot opens scripts in Neovim"
    return 0
  fi
  files=("$dir"/editor_settings-*.tres)
  if [[ ! -e ${files[0]} ]]; then
    version=$(godot --version 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+') || return 0
    files=("$dir/editor_settings-$version.tres")
    mkdir -p "$dir"
    printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' >"${files[0]}"
  fi
  for f in "${files[@]}"; do godot_editor "$f"; done
}

# godot_uninstall: godot's own script editor again, in each settings file where install set godot-nvim
godot_uninstall() {
  local f
  if pgrep -x godot >/dev/null; then
    warn "Godot is open, so it still opens scripts with godot-nvim: close it and run dot uninstall again"
    return 0
  fi
  for f in "${XDG_CONFIG_HOME:-$HOME/.config}"/godot/editor_settings-*.tres; do
    [[ -f $f ]] || continue
    grep -qE '^text_editor/external/exec_path = ".*/godot-nvim"$' "$f" || continue
    say "giving godot its own script editor back in $(basename "$f")"
    grep -vE '^text_editor/external/(use_external_editor|exec_path|exec_flags) = ' "$f" >"$f.new" || true
    mv -f "$f.new" "$f"
  done
}

# godot_editor <settings file>: godot-nvim as godot's external editor; the other settings stay
godot_editor() {
  local want line missing=0
  want=$(printf '%s\n' \
    'text_editor/external/use_external_editor = true' \
    "text_editor/external/exec_path = \"$HOME/.local/bin/godot-nvim\"" \
    'text_editor/external/exec_flags = "{project} {file} {line} {col}"')
  while read -r line; do grep -qxF "$line" "$1" || missing=1; done <<<"$want"
  ((missing)) || return 0
  say "setting godot's external editor to neovim in $(basename "$1")"
  {
    grep -vE '^text_editor/external/(use_external_editor|exec_path|exec_flags) = ' "$1" || true
    echo "$want"
  } >"$1.new"
  mv -f "$1.new" "$1"
}
