# shared/claude.sh: claude code: the cli, its settings, plugins and mcp servers, and what the servers need
# shellcheck shell=bash

claude_install() {
  claude_cli
  have claude || return 0
  claude_settings
  claude_plugins
  claude_skills
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
  claude_skills
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

# claude_skills: the skill packs in shared/claude-skills.txt, each cloned at its commit into
# ~/.local/share/claude-skills/<name>, with each of its skills linked into ~/.claude/skills; a skill of
# your own by the same name stays, and links to skills no listed pack has any more go
claude_skills() {
  local share=${XDG_DATA_HOME:-$HOME/.local/share}/claude-skills skills=$HOME/.claude/skills
  local name repo commit folder dir skill link
  local -A keep=()
  mkdir -p "$skills"
  while read -r name repo commit folder; do
    dir=$share/$name
    if [[ $(git -C "$dir" rev-parse HEAD 2>/dev/null) != "$commit" ]]; then
      say "getting claude's $name skills"
      if { [[ -d $dir/.git ]] || GIT_TERMINAL_PROMPT=0 quiet git clone --quiet --filter=blob:none --no-checkout "$repo" "$dir"; } &&
        GIT_TERMINAL_PROMPT=0 quiet git -C "$dir" fetch --quiet --filter=blob:none origin "$commit" &&
        quiet git -C "$dir" checkout --quiet --detach "$commit"; then
        :
      else
        warn "couldn't get $name's skills at $commit, so the ones it has stay"
      fi
    fi
    for skill in "$dir/$folder"/*/; do
      skill=${skill%/}
      link=$skills/${skill##*/}
      [[ -f $skill/SKILL.md ]] || continue
      if [[ $(readlink "$link") != "$skill" ]]; then
        if [[ -e $link || -L $link ]] && [[ $(readlink "$link") != "$share"/* ]]; then
          warn "claude has a ${skill##*/} skill of your own, so $name's is left out"
          continue
        fi
        ln -sfn "$skill" "$link"
      fi
      keep[$link]=1
    done
  done < <(list "$DOTFILES/shared/claude-skills.txt")
  for link in "$skills"/*; do
    if [[ -L $link && $(readlink "$link") == "$share"/* && -z ${keep[$link]:-} ]]; then rm -f "$link"; fi
  done
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
  # unity's own server, in the unity cli: the editor open on the project claude runs in, through the
  # project's pipeline package (unity-project adds it)
  if [[ -x $HOME/.local/bin/unity ]]; then
    claude_server unity -e UNITY_NO_CLI_INVOKED_TELEMETRY=1 -e UNITY_NO_CRASH_REPORT=1 -e UNITY_NO_AGENT_HINTS=1 \
      -e UNITY_NO_UPDATE_CHECK=1 -- "$HOME/.local/bin/unity" mcp
  fi
  if [[ ! -x $cargo/bin/bevy_brp_mcp ]]; then
    say "building bevy_brp_mcp, bevy's mcp server"
    cargo install --quiet bevy_brp_mcp </dev/null || todo "bevy_brp_mcp didn't build, so Claude has no Bevy server yet: run dot install again"
  fi
  if [[ -x $cargo/bin/bevy_brp_mcp ]]; then claude_server brp -- "$cargo/bin/bevy_brp_mcp"; fi
  claude_blender
  claude_server blender -e DISABLE_TELEMETRY=true -- uvx mcp-for-blender@latest
  # blender lab's own server, beside it, on the port its add-on is set to (claude_blender_lab)
  if compgen -G "${XDG_CONFIG_HOME:-$HOME/.config}/blender/*/extensions/blender_lab/mcp" >/dev/null; then
    claude_server blender_official -e BLENDER_MCP_HOST=127.0.0.1 -e BLENDER_MCP_PORT=9877 \
      -- "$HOME/.local/bin/blender-lab-mcp"
  fi
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

# claude_blender [update]: the mcp for blender add-on and blender lab's official one, turned on in
# blender's preferences while blender is closed, and mcp for blender's telemetry prompt answered no
claude_blender() {
  local series config addons prefs community=0 lab=0 consent=$HOME/.config/blender-mcp/consent_prompt.json
  have blender || return 0
  if [[ ! -e $consent ]]; then
    mkdir -p "$(dirname "$consent")"
    echo '{"prompt_version": 2, "action": "decline", "consent": false}' >"$consent"
  fi
  series=$(blender --version 2>/dev/null | sed -n 's/^Blender \([0-9]*\.[0-9]*\).*/\1/p' | head -n 1)
  [[ -n $series ]] || return 0
  config=${XDG_CONFIG_HOME:-$HOME/.config}/blender/$series
  addons=$config/scripts/addons prefs=$config/config/userpref.blend
  if [[ ! -f $addons/blender_mcp.py || ${1:-} == update ]]; then
    [[ -f $addons/blender_mcp.py ]] || say "installing the mcp for blender add-on"
    uvx mcp-for-blender@latest install-addon --addons-dir "$addons" >/dev/null </dev/null ||
      warn "couldn't install the mcp for blender add-on"
  fi
  if [[ -f $addons/blender_mcp.py ]] && ! grep -qa blender_mcp "$prefs" 2>/dev/null; then community=1; fi
  # blender lab's needs blender 5.1
  if [[ $(printf '%s\n' 5.1 "$series" | sort -V | head -n 1) == 5.1 ]]; then
    if [[ ! -d $config/extensions/blender_lab/mcp ]] || ! grep -qa bl_ext.blender_lab.mcp "$prefs" 2>/dev/null; then
      lab=1
    elif [[ ${1:-} == update ]] && ! pgrep -x blender >/dev/null; then
      # --sync fetches the repos' listings first; without it, nothing newer is ever seen
      blender --online-mode -c extension update --sync >/dev/null 2>&1 </dev/null || warn "couldn't update blender's extensions"
    fi
  fi
  ((community || lab)) || return 0
  if pgrep -x blender >/dev/null; then
    todo "close Blender and run dot install again, so its MCP add-ons get turned on"
    return 0
  fi
  if ((community)); then
    say "turning on the mcp for blender add-on"
    blender --background --python-exit-code 1 --python-expr 'import addon_utils, bpy
assert addon_utils.enable("blender_mcp", default_set=True, persistent=True)
bpy.ops.wm.save_userpref()' >/dev/null 2>&1 </dev/null || warn "couldn't turn on the mcp for blender add-on"
  fi
  if ((lab)); then claude_blender_lab "$config"; fi
}

# claude_blender_lab <config dir>: blender lab's official mcp add-on, from the blender lab extensions
# repo, turned on and started with blender, on port 9877, as mcp for blender's has 9876. it works only
# with blender's online access on, so that's turned on too
claude_blender_lab() {
  if [[ ! -d $1/extensions/blender_lab/mcp ]]; then
    say "installing blender lab's mcp add-on"
    if [[ ! -d $1/extensions/blender_lab ]]; then
      blender -c extension repo-add blender_lab --name "Blender Lab" --url https://lab.blender.org/ >/dev/null 2>&1 </dev/null ||
        { warn "couldn't add the blender lab extensions repo"; return 0; }
    fi
    blender --online-mode -c extension install --sync blender_lab.mcp >/dev/null 2>&1 </dev/null ||
      { warn "couldn't install blender lab's mcp add-on"; return 0; }
  fi
  say "turning on blender lab's mcp add-on"
  blender --background --python-exit-code 1 --python-expr 'import addon_utils, bpy
p = bpy.context.preferences
p.system.use_online_access = True
assert addon_utils.enable("bl_ext.blender_lab.mcp", default_set=True, persistent=True)
a = p.addons["bl_ext.blender_lab.mcp"].preferences
a.port = 9877
a.use_autostart = True
bpy.ops.wm.save_userpref()' >/dev/null 2>&1 </dev/null || warn "couldn't turn on blender lab's mcp add-on"
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
