# shared/claude.sh: claude code: the cli, its settings, plugins and mcp servers, and what the servers need
# shellcheck shell=bash

claude_install() {
  claude_cli
  have claude || return 0
  claude_settings
  claude_plugins
  claude_servers
}

claude_update() {
  have claude || return 0
  claude update </dev/null || warn "couldn't update claude code"
  claude_settings
  claude plugin marketplace update >/dev/null </dev/null || warn "couldn't update claude's marketplaces"
  claude_plugins
  local id
  while read -r id; do
    claude plugin update "$id" --scope user >/dev/null </dev/null || warn "couldn't update $id"
  done < <(list "$DOTFILES/shared/claude-plugins.txt")
  say "updating the tools claude's mcp servers use"
  cargo install --quiet bevy_brp_mcp </dev/null || warn "couldn't update bevy_brp_mcp"
  quiet npx -y @playwright/mcp@latest install-browser chromium || warn "couldn't update playwright's chromium"
  npx -y -p rea-agents@latest rea setup --skill-client claude_code --yes >/dev/null </dev/null || warn "couldn't update rea's skill"
  claude_blender update
  claude_servers
}

# claude_cli: claude code from its own installer, when it isn't there
claude_cli() {
  local tmp
  have claude && return 0
  say "installing claude code"
  tmp=$(mktemp -d)
  if fetch https://claude.ai/install.sh "$tmp/install.sh"; then
    bash "$tmp/install.sh" </dev/null || warn "claude code's installer failed"
  else
    warn "couldn't download claude code's installer"
  fi
  rm -rf "$tmp"
}

# claude_settings: shared/claude-settings.json merged into ~/.claude/settings.json; your own keys stay,
# and the permission rules are both lists together
claude_settings() {
  local file=$HOME/.claude/settings.json merged
  mkdir -p "$HOME/.claude"
  [[ -s $file ]] || echo '{}' >"$file"
  if ! merged=$(jq -s '.[0] as $mine | .[1] as $ours | $mine * $ours
    | .permissions.deny = (($mine.permissions.deny // []) + $ours.permissions.deny | unique)
    | .permissions.ask = (($mine.permissions.ask // []) + $ours.permissions.ask | unique)' \
    "$file" "$DOTFILES/shared/claude-settings.json" 2>/dev/null); then
    warn "claude's settings.json isn't valid json, so it's left as it is"
    return 0
  fi
  [[ $merged == "$(jq . "$file")" ]] && return 0
  say "merging claude's settings"
  printf '%s\n' "$merged" >"$file.new"
  mv -f "$file.new" "$file"
}

# claude_plugins: the marketplaces, then the plugins, each one only when it's missing
claude_plugins() {
  local name repo id markets plugins
  markets=$(claude plugin marketplace list --json 2>/dev/null </dev/null | jq -r '.[].name')
  while read -r name repo; do
    grep -qxF "$name" <<<"$markets" && continue
    say "adding claude's $name marketplace"
    claude plugin marketplace add "$repo" >/dev/null </dev/null || warn "couldn't add the $name marketplace"
  done < <(list "$DOTFILES/shared/claude-marketplaces.txt")
  plugins=$(claude plugin list --json 2>/dev/null </dev/null | jq -r '.[] | select(.scope == "user") | .id')
  while read -r id; do
    grep -qxF "$id" <<<"$plugins" && continue
    say "installing claude's $id plugin"
    claude plugin install "$id" --scope user >/dev/null </dev/null || warn "couldn't install $id"
  done < <(list "$DOTFILES/shared/claude-plugins.txt")
}

# claude_servers: the mcp servers, at user scope, and what each needs; one claude already has by that
# name stays as it is
claude_servers() {
  local cargo=${CARGO_HOME:-$HOME/.cargo}
  if ! claude mcp get github >/dev/null 2>&1 </dev/null; then
    say "adding the github mcp server, signed in through gh"
    claude mcp add-json --scope user github "$(jq -nc --arg helper "$HOME/.local/bin/claude-github-headers" \
      '{type: "http", url: "https://api.githubcopilot.com/mcp/", headersHelper: $helper}')" >/dev/null </dev/null ||
      warn "couldn't add the github mcp server"
  fi
  claude_server godot-mcp-toolkit -- npx -y @npgamedev/godot-mcp-server@latest
  if [[ ! -x $cargo/bin/bevy_brp_mcp ]]; then
    say "building bevy_brp_mcp, bevy's mcp server"
    cargo install --quiet bevy_brp_mcp </dev/null || todo "bevy_brp_mcp didn't build, so Claude has no Bevy server yet: run dot install again"
  fi
  if [[ -x $cargo/bin/bevy_brp_mcp ]]; then claude_server brp -- "$cargo/bin/bevy_brp_mcp"; fi
  claude_blender
  claude_server blender -e DISABLE_TELEMETRY=true -- uvx mcp-for-blender@latest
  if ! compgen -G "$HOME/.cache/ms-playwright/chromium-*" >/dev/null; then
    say "installing chromium for playwright"
    quiet npx -y @playwright/mcp@latest install-browser chromium || warn "couldn't install playwright's chromium"
  fi
  claude_server playwright -- npx -y @playwright/mcp@latest --browser chromium --isolated
  claude_ghidra
  if ! claude mcp get rea >/dev/null 2>&1 </dev/null; then
    claude_server rea -e "GHIDRA_INSTALL_DIR=$HOME/.local/opt/ghidra" -e REA_ANALYSIS_PROVIDER=ghidra \
      -- npx -y -p rea-agents@latest rea mcp
    npx -y -p rea-agents@latest rea setup --skill-client claude_code --yes >/dev/null </dev/null || warn "couldn't set up rea's skill"
  fi
}

# claude_server <name> [-e KEY=value]... -- <command> [arg]...: adds a stdio server, unless claude has one by that name
claude_server() {
  local name=$1
  shift
  claude mcp get "$name" >/dev/null 2>&1 </dev/null && return 0
  say "adding the $name mcp server"
  claude mcp add --scope user "$name" "$@" >/dev/null </dev/null || warn "couldn't add the $name mcp server"
}

# claude_blender [update]: the mcp for blender add-on, turned on in blender's preferences while blender
# is closed, and its telemetry prompt answered no
claude_blender() {
  local series addons prefs consent=$HOME/.config/blender-mcp/consent_prompt.json
  have blender || return 0
  if [[ ! -e $consent ]]; then
    mkdir -p "$(dirname "$consent")"
    echo '{"prompt_version": 2, "action": "decline", "consent": false}' >"$consent"
  fi
  series=$(blender --version 2>/dev/null | sed -n 's/^Blender \([0-9]*\.[0-9]*\).*/\1/p' | head -n 1)
  [[ -n $series ]] || return 0
  addons=$HOME/.config/blender/$series/scripts/addons
  prefs=$HOME/.config/blender/$series/config/userpref.blend
  if [[ ! -f $addons/blender_mcp.py || ${1:-} == update ]]; then
    [[ -f $addons/blender_mcp.py ]] || say "installing the mcp for blender add-on"
    uvx mcp-for-blender@latest install-addon --addons-dir "$addons" >/dev/null </dev/null ||
      { warn "couldn't install the mcp for blender add-on"; return 0; }
  fi
  if [[ -f $prefs ]] && grep -qa blender_mcp "$prefs"; then return 0; fi
  if pgrep -x blender >/dev/null; then
    todo "close Blender and run dot install again, so the MCP for Blender add-on gets turned on"
    return 0
  fi
  say "turning on the mcp for blender add-on"
  blender --background --python-expr 'import addon_utils, bpy
addon_utils.enable("blender_mcp", default_set=True, persistent=True)
bpy.ops.wm.save_userpref()' >/dev/null 2>&1 </dev/null || warn "couldn't turn on the mcp for blender add-on"
}

# claude_ghidra: rea's engine: ghidra's newest release in ~/.local/opt/ghidra-<tag>, linked as
# ~/.local/opt/ghidra, and the one the link named before removed; a ghidra of your own there stays
claude_ghidra() {
  local opt=$HOME/.local/opt tag url dir tmp old
  if [[ -e $opt/ghidra && ! -L $opt/ghidra ]]; then return 0; fi
  tag=$(gh_tag NationalSecurityAgency/ghidra) || tag=""
  [[ -n $tag ]] || { warn "couldn't look up ghidra's newest release"; return 0; }
  dir=$opt/ghidra-$tag
  if [[ ! -d $dir ]]; then
    say "downloading ghidra $tag, for rea"
    url=$(gh_asset NationalSecurityAgency/ghidra '^ghidra_.*_PUBLIC_.*\.zip$') || url=""
    tmp=$(mktemp -d)
    if [[ -n $url ]] && fetch "$url" "$tmp/ghidra.zip" && unzip -q "$tmp/ghidra.zip" -d "$tmp/zip"; then
      mkdir -p "$opt"
      mv "$tmp"/zip/ghidra_* "$dir"
    else
      warn "couldn't download ghidra"
    fi
    rm -rf "$tmp"
    [[ -d $dir ]] || return 0
  fi
  old=$(readlink "$opt/ghidra") || old=""
  [[ $old != "ghidra-$tag" ]] || return 0
  ln -sfn "ghidra-$tag" "$opt/ghidra"
  if [[ $old == ghidra-Ghidra_* && -d $opt/$old ]]; then rm -rf "${opt:?}/$old"; fi
}
