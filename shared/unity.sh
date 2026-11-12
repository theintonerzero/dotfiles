# shared/unity.sh: the unity cli, which drives unity editors and the hub from the shell and serves
# claude's unity mcp server, and the terminal unity's neovim package opens neovim in; the hub comes from
# its dnf repo, and unity-project sets up a project
# shellcheck shell=bash

unity_install() {
  unity_cli
  unity_neovim
}

unity_update() {
  local bin=$HOME/.local/bin/unity
  if [[ -x $bin ]]; then
    say "updating the unity cli"
    quiet "$bin" self-update --yes --non-interactive || warn "couldn't update the unity cli"
  else
    unity_cli
  fi
  unity_neovim
}

# unity_cli: the unity cli from unity's installer, in ~/.local/bin, when it isn't there; with SHELL=/bin/sh
# the installer edits no shell config (zsh's is linked from here, and has ~/.local/bin on the path), and
# UNITY_CLI_SKIP_SETUP leaves claude's skills to unity's plugin
unity_cli() {
  local tmp
  [[ -x $HOME/.local/bin/unity ]] && return 0
  say "installing the unity cli"
  tmp=$(mktemp -d)
  if fetch https://unity.com/install.sh "$tmp/install.sh"; then
    SHELL=/bin/sh UNITY_CLI_SKIP_SETUP=1 quiet bash "$tmp/install.sh" || warn "the unity cli's installer failed"
  else
    warn "couldn't download the unity cli's installer"
  fi
  rm -rf "$tmp"
  [[ -x $HOME/.local/bin/unity ]] ||
    todo "the Unity CLI didn't install, so Claude has no Unity server yet: run dot install again"
}

# unity_pref <key>: a string from unity's editor prefs (an xml file of base64 values), or nothing
unity_pref() {
  local prefs=${XDG_DATA_HOME:-$HOME/.local/share}/unity3d/prefs value
  [[ -f $prefs ]] || return 0
  value=$(sed -n "s|^[[:space:]]*<pref name=\"$1\" type=\"string\">\([^<]*\)</pref>.*|\1|p" "$prefs" | head -n 1)
  [[ -z $value ]] || base64 -d <<<"$value" 2>/dev/null || true
}

# unity_pref_set <key> <value>: a string in unity's editor prefs, in place of any it had; only while
# unity is closed, as it writes the prefs it keeps in memory back over the file on exit
unity_pref_set() {
  local prefs=${XDG_DATA_HOME:-$HOME/.local/share}/unity3d/prefs value
  value=$(printf '%s' "$2" | base64 -w 0)
  awk -v key="$1" -v value="$value" '
    index($0, "<pref name=\"" key "\" ") { next }
    /^<\/unity_prefs>/ { printf "\t<pref name=\"%s\" type=\"string\">%s</pref>\n", key, value }
    { print }
  ' "$prefs" >"$prefs.new"
  if grep -qF "<pref name=\"$1\" " "$prefs.new"; then
    mv -f "$prefs.new" "$prefs"
  else
    rm -f "$prefs.new"
    warn "unity's editor prefs have no closing tag, so $1 is left as it is"
    return 1
  fi
}

# unity_running: whether a unity editor is open; it names its process after its main thread, so it's
# found by its path
unity_running() { pgrep -f '/Editor/Unity( |$)' >/dev/null; }

# unity_neovim: neovim as unity's script editor, through unity's neovim package (com.walcht.ide.neovim,
# which unity-project adds), which opens it through x-terminal-emulator, so in the default terminal, as
# its own ghostty command leaves a quote open and never starts. both live in unity's editor prefs, so
# this waits for unity to be closed; an editor or a terminal you chose, other than ghostty, stays. a
# project without the package would start neovim with no terminal, so every project gets unity-project
unity_neovim() {
  local prefs=${XDG_DATA_HOME:-$HOME/.local/share}/unity3d/prefs nvim args old app json
  [[ -f $prefs ]] || return 0
  nvim=$(command -v nvim) || return 0
  args='-T "nvimunity-{instanceId}" -e {app} {filePath} --listen {serverSocket} --cmd ":lua'
  args+=" _G.nvim_unity_user_supplied_project_root_dir='{projectRootDir}'"
  args+=" _G.nvim_unity_analyzer_diagnostic_scope='{analyzerDiagnosticScope}'"
  args+=" _G.nvim_unity_compiler_diagnostic_scope='{compilerDiagnosticScope}'\""
  old=$(unity_pref NvimUnityConfigJson)
  [[ -n $old ]] || old='{}'
  if ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$old"; then
    warn "unity's neovim settings aren't valid json, so they're left as they are"
    return 0
  fi
  case $(jq -r '.TermLaunchCmd // ""' <<<"$old") in
    "" | ghostty | */ghostty) json=$(jq -c --arg args "$args" '.TermLaunchCmd = "x-terminal-emulator" | .TermLaunchArgs = $args' <<<"$old") ;;
    *) json="" ;;
  esac
  app=$(unity_pref kScriptsDefaultApp)
  [[ -n $json || -z $app ]] || return 0
  if unity_running; then
    todo "close Unity and run dot install again, so Unity opens scripts in Neovim, in Ghostty"
    return 0
  fi
  say "setting unity to open scripts in neovim, in the default terminal"
  if [[ -n $json ]]; then unity_pref_set NvimUnityConfigJson "$json" || return 0; fi
  if [[ -z $app ]]; then unity_pref_set kScriptsDefaultApp "$nvim" || return 0; fi
}

# unity_vulkan <project>: the project's linux editor and builds on vulkan alone (graphics api 21; the
# list is little-endian hex, with unity's i after it), in place of unity's automatic choice, which is
# opengl. an editor open on the project sets it through unity, as it would write its own back over the
# file; it takes effect when unity next opens the project
unity_vulkan() {
  local project settings
  project=$(realpath "$1") settings=$1/ProjectSettings/ProjectSettings.asset
  [[ -f $settings ]] || return 0
  if have unity && unity editors running --format json 2>/dev/null |
    jq -e --arg p "$project" '.data.items[]? | select(.projectPath == $p)' >/dev/null; then
    say "setting $project's linux graphics to vulkan alone, in its open editor"
    unity command script eval --project-path "$project" --caller plugin --skill unity-cli \
      'UnityEditor.PlayerSettings.SetUseDefaultGraphicsAPIs(UnityEditor.BuildTarget.StandaloneLinux64, false);
       UnityEditor.PlayerSettings.SetGraphicsAPIs(UnityEditor.BuildTarget.StandaloneLinux64,
         new[] { UnityEngine.Rendering.GraphicsDeviceType.Vulkan });
       UnityEditor.AssetDatabase.SaveAssets(); return "vulkan";' >/dev/null ||
      todo "close Unity and run unity-project again in $project, so it runs on Vulkan"
    return 0
  fi
  awk '
    function linux() { print "  - m_BuildTarget: LinuxStandaloneSupport"; print "    m_APIs: 15000000i"; print "    m_Automatic: 0" }
    /^  m_BuildTargetGraphicsAPIs: \[\]$/ { print "  m_BuildTargetGraphicsAPIs:"; linux(); next }
    /^  m_BuildTargetGraphicsAPIs:$/ { print; list = 1; next }
    list && /^  - m_BuildTarget: LinuxStandaloneSupport$/ { print; mine = found = 1; next }
    list && /^  - / { mine = 0; print; next }
    list && /^    / { if (mine && /^    m_APIs: /) print "    m_APIs: 15000000i"; else if (mine && /^    m_Automatic: /) print "    m_Automatic: 0"; else print; next }
    list { if (!found) linux(); list = 0 }
    { print }
    END { if (list && !found) linux() }
  ' "$settings" >"$settings.new"
  if cmp -s "$settings" "$settings.new"; then
    rm -f "$settings.new"
  else
    say "setting $project's linux graphics to vulkan alone"
    mv -f "$settings.new" "$settings"
  fi
}
