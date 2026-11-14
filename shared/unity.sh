# shared/unity.sh: the unity cli, which drives unity editors and the hub from the shell and serves
# claude's unity mcp server, and unity's script editor: neovim, in the terminal unity's neovim package
# opens it in, on linux, and vscodium on macos, where that package isn't finished; the hub comes from
# its dnf repo or homebrew's cask, and unity-project sets up a project
# shellcheck shell=bash

unity_install() {
  unity_cli
  unity_analytics
  unity_editor
  unity_ready
}

# unity_editor: unity's script editor, as this os has it
unity_editor() {
  if [[ $(os_id) == macos ]]; then unity_vscodium; else unity_neovim; fi
}

# unity_vscodium: vscodium as unity's script editor on macos, where unity keeps its editor prefs in a
# preferences domain; an editor you chose stays, and it waits for unity to be closed, as unity writes
# the prefs it holds back when it quits
unity_vscodium() {
  local domain=com.unity3d.UnityEditor5.x app=$APPS/VSCodium.app current
  [[ -d $app ]] || return 0
  current=$(defaults read "$domain" kScriptsDefaultApp 2>/dev/null) || current=""
  [[ -z $current ]] || return 0
  if unity_running; then
    todo "close Unity and run dot install again, so Unity opens scripts in VSCodium"
    return 0
  fi
  say "setting unity to open scripts in vscodium"
  defaults write "$domain" kScriptsDefaultApp -string "$app" || warn "couldn't set unity's script editor"
}

# unity_analytics: unity's usage analytics off; the cli and the hub share the choice, and the UNITY_NO_*
# variables stop only the cli's anonymous ping, its crash reports, tips and update check. checked each
# run, as signing in can bring them back
unity_analytics() {
  local bin=$HOME/.local/bin/unity
  [[ -x $bin ]] || return 0
  "$bin" analytics status --format json 2>/dev/null </dev/null | jq -e '.data.optedIn == false' >/dev/null && return 0
  say "turning off unity's usage analytics"
  quiet "$bin" analytics opt-out || warn "couldn't turn off unity's usage analytics"
}

# unity_ready: what only you can do before claude can make a game: sign in, which the editor's licence
# needs, and install an editor, which these dotfiles leave to you, as each is several gb
unity_ready() {
  local bin=$HOME/.local/bin/unity editors
  [[ -x $bin ]] || return 0
  "$bin" auth status >/dev/null 2>&1 </dev/null ||
    todo "sign in to Unity: open Unity Hub, or run unity auth login"
  editors=$("$bin" editors --installed --format json 2>/dev/null </dev/null | jq '.data.items | length') || editors=0
  [[ ${editors:-0} -gt 0 ]] ||
    todo "install a Unity Editor in Unity Hub (these dotfiles were checked with 6000.6), and accept its terms when it first opens"
}

# unity_uninstall: unity's own script editor and terminal again, where install set neovim and
# x-terminal-emulator, as uninstall removes x-terminal-emulator; only while unity is closed
unity_uninstall() {
  local prefs=${XDG_DATA_HOME:-$HOME/.local/share}/unity3d/prefs json term app
  if [[ $(os_id) == macos ]]; then
    app=$(defaults read com.unity3d.UnityEditor5.x kScriptsDefaultApp 2>/dev/null) || app=""
    [[ $app == "$APPS/VSCodium.app" ]] || return 0
    if unity_running; then
      warn "Unity is open, so it still opens scripts in VSCodium: close it and run dot uninstall again"
      return 0
    fi
    say "giving unity its own script editor back"
    defaults delete com.unity3d.UnityEditor5.x kScriptsDefaultApp || true
    return 0
  fi
  [[ -s $prefs ]] || return 0
  json=$(unity_pref NvimUnityConfigJson)
  term=$(jq -r '.TermLaunchCmd? // ""' 2>/dev/null <<<"$json") || term=""
  app=$(unity_pref kScriptsDefaultApp)
  [[ $term == x-terminal-emulator || $app == */nvim ]] || return 0
  if unity_running; then
    warn "Unity is open, so it still opens scripts in Neovim: close it and run dot uninstall again"
    return 0
  fi
  say "giving unity its own script editor back"
  if [[ $app == */nvim ]]; then unity_pref_del kScriptsDefaultApp; fi
  if [[ $term == x-terminal-emulator ]]; then
    json=$(jq -c 'del(.TermLaunchCmd, .TermLaunchArgs)' <<<"$json")
    if [[ $json == '{}' ]]; then unity_pref_del NvimUnityConfigJson; else unity_pref_set NvimUnityConfigJson "$json" || true; fi
  fi
}

unity_update() {
  local bin=$HOME/.local/bin/unity
  if [[ -x $bin ]]; then
    say "updating the unity cli"
    quiet "$bin" self-update --yes --non-interactive || warn "couldn't update the unity cli"
  else
    unity_cli
  fi
  unity_analytics
  unity_editor
}

# unity_cli: the unity cli from unity's installer, in ~/.local/bin, when it isn't there; with SHELL=/bin/sh
# the installer edits no shell config (zsh's is linked from here, and has ~/.local/bin on the path), and
# UNITY_CLI_SKIP_SETUP leaves claude's skills to unity's plugin. on macos the installer puts it in
# ~/.unity/bin, so ~/.local/bin/unity is a link to it there
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
  if [[ ! -e $HOME/.local/bin/unity && -x $HOME/.unity/bin/unity ]]; then
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$HOME/.unity/bin/unity" "$HOME/.local/bin/unity"
  fi
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

# unity_pref_del <key>: a key out of unity's editor prefs; only while unity is closed
unity_pref_del() {
  local prefs=${XDG_DATA_HOME:-$HOME/.local/share}/unity3d/prefs
  awk -v key="$1" 'index($0, "<pref name=\"" key "\" ") { next } { print }' "$prefs" >"$prefs.new" &&
    mv -f "$prefs.new" "$prefs"
}

# unity_running: whether a unity editor is open; it names its process after its main thread, so it's
# found by its path, which on macos is inside Unity.app
unity_running() { pgrep -f '(/Editor/Unity|/Unity\.app/Contents/MacOS/Unity)( |$)' >/dev/null; }

# unity_neovim: neovim as unity's script editor, through unity's neovim package (com.walcht.ide.neovim,
# which unity-project adds), which opens it through x-terminal-emulator, so in the default terminal, as
# its own ghostty command leaves a quote open and never starts. both live in unity's editor prefs, so
# this waits for unity to be closed; an editor or a terminal you chose, other than ghostty, stays. a
# project without the package would start neovim with no terminal, so every project gets unity-project.
# before unity's first run there are no prefs, so they start as an empty file, which unity fills in
unity_neovim() {
  local prefs=${XDG_DATA_HOME:-$HOME/.local/share}/unity3d/prefs nvim args old app json
  nvim=$(command -v nvim) || return 0
  if [[ ! -s $prefs ]] && ! unity_running; then
    mkdir -p "$(dirname "$prefs")"
    printf '<unity_prefs version_major="1" version_minor="1">\n</unity_prefs>\n' >"$prefs"
  fi
  [[ -s $prefs ]] || return 0
  args='-T "nvimunity-{instanceId}" -e {app} {filePath} --listen {serverSocket} --cmd ":lua'
  args+=" _G.nvim_unity_user_supplied_project_root_dir='{projectRootDir}'"
  args+=" _G.nvim_unity_analyzer_diagnostic_scope='{analyzerDiagnosticScope}'"
  args+=" _G.nvim_unity_compiler_diagnostic_scope='{compilerDiagnosticScope}'\""
  old=$(unity_pref NvimUnityConfigJson)
  [[ -n $old ]] || old='{}'
  json=""
  if ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$old"; then
    warn "unity's neovim settings aren't valid json, so they're left as they are"
  else
    case $(jq -r '.TermLaunchCmd // ""' <<<"$old") in
      "" | ghostty | */ghostty) json=$(jq -c --arg args "$args" '.TermLaunchCmd = "x-terminal-emulator" | .TermLaunchArgs = $args' <<<"$old") ;;
    esac
  fi
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
  if unity_open_on "$project"; then
    say "setting $project's linux graphics to vulkan alone, in its open editor"
    unity command script eval --project-path "$project" \
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
  # a file in a shape this doesn't know (crlf line ends, binary serialization) comes through unchanged
  awk '/^  - m_BuildTarget: LinuxStandaloneSupport$/ { mine = 1; next } /^  - / { mine = 0 }
    mine && /^    m_APIs: 15000000i$/ { api = 1 } mine && /^    m_Automatic: 0$/ { auto = 1 }
    END { exit !(api && auto) }' "$settings" ||
    todo "set $project to Vulkan alone yourself (Project Settings > Player > Linux > Graphics APIs), as its settings file has a shape unity-project doesn't know"
}

# unity_open_on <project>: whether a unity editor has the project open, by its path, symlinks resolved,
# or by the lock file an editor keeps in the project while unity runs
unity_open_on() {
  local project path
  project=$(realpath "$1")
  if have unity; then
    while read -r path; do
      [[ -n $path && $(realpath "$path" 2>/dev/null) == "$project" ]] && return 0
    done < <(unity editors running --format json 2>/dev/null </dev/null | jq -r '.data.items[]?.projectPath // empty')
  fi
  [[ -e $project/Temp/UnityLockfile ]] && unity_running
}
