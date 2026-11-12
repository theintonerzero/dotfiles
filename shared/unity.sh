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

# unity_neovim: unity's neovim package (com.walcht.ide.neovim, which unity-project adds) opens neovim
# through x-terminal-emulator, so in the default terminal; its own ghostty command leaves a quote open
# and never starts. the package keeps its settings as json in unity's editor prefs, which unity, keeping
# them while it runs, writes back over the file on exit, so this waits for unity to be closed; a
# terminal you chose in its settings, other than ghostty, stays
unity_neovim() {
  local prefs=${XDG_DATA_HOME:-$HOME/.local/share}/unity3d/prefs key=NvimUnityConfigJson
  local args old="" json value
  [[ -f $prefs ]] || return 0
  args='-T "nvimunity-{instanceId}" -e {app} {filePath} --listen {serverSocket} --cmd ":lua'
  args+=" _G.nvim_unity_user_supplied_project_root_dir='{projectRootDir}'"
  args+=" _G.nvim_unity_analyzer_diagnostic_scope='{analyzerDiagnosticScope}'"
  args+=" _G.nvim_unity_compiler_diagnostic_scope='{compilerDiagnosticScope}'\""
  value=$(sed -n "s|^[[:space:]]*<pref name=\"$key\" type=\"string\">\([^<]*\)</pref>.*|\1|p" "$prefs" | head -n 1)
  if [[ -n $value ]]; then old=$(base64 -d <<<"$value" 2>/dev/null) || old=""; fi
  [[ -n $old ]] || old='{}'
  if ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$old"; then
    warn "unity's neovim settings aren't valid json, so they're left as they are"
    return 0
  fi
  case $(jq -r '.TermLaunchCmd // ""' <<<"$old") in
    "" | ghostty | */ghostty) ;;
    *) return 0 ;;
  esac
  # the editor names its process after its main thread, so it's found by its path
  if pgrep -f '/Editor/Unity( |$)' >/dev/null; then
    todo "close Unity and run dot install again, so Unity's Neovim package opens Neovim in Ghostty"
    return 0
  fi
  say "setting unity's neovim package to open neovim in the default terminal"
  json=$(jq -c --arg args "$args" '.TermLaunchCmd = "x-terminal-emulator" | .TermLaunchArgs = $args' <<<"$old")
  value=$(printf '%s' "$json" | base64 -w 0)
  awk -v key="$key" -v value="$value" '
    index($0, "<pref name=\"" key "\" ") { next }
    /^<\/unity_prefs>/ { printf "\t<pref name=\"%s\" type=\"string\">%s</pref>\n", key, value }
    { print }
  ' "$prefs" >"$prefs.new"
  if grep -qF "<pref name=\"$key\" " "$prefs.new"; then
    mv -f "$prefs.new" "$prefs"
  else
    rm -f "$prefs.new"
    warn "unity's editor prefs have no closing tag, so unity's neovim settings are left as they are"
  fi
}
