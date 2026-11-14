# macos/steps.sh: the order macos's steps run in, for install, update and uninstall
# shellcheck shell=bash

os_install() {
  system_first
  ask_questions
  keep_sudo
  set_hostname
  system_install
  apps_install
  link_home
  gui_env
  shell_install
  git_install
  toolchains_install
  neovim_install
  vscodium_install
  godot_install
  unity_install
  claude_install
  desktop_install
  bar_install
  security_install
  llm_install
}

# macos's settings stay as you left them: desktop_install, bar_install and security_install are install's
# alone; a running bar only reads its config again
os_update() {
  keep_sudo
  system_update
  apps_update
  link_home
  bar_update
  shell_update
  toolchains_update
  neovim_update
  vscodium_update
  unity_update
  claude_update
  godot_update
  llm_update
}

os_uninstall() {
  say "removing the links"
  unlink_home
  apps_uninstall
  bar_uninstall
  neovim_uninstall
  godot_uninstall
  unity_uninstall
}

# os_uninstall_notes: what uninstall leaves behind, said once it's done
os_uninstall_notes() {
  cat <<'NOTES'

These stay, so remove them yourself if you want them gone:
  - Homebrew, its formulae and casks, and Xcode
  - macOS's settings, the wallpaper and the Dock's apps, Touch ID for sudo (/etc/pam.d/sudo_local, and
    /usr/local/lib/pam/pam_reattach.so, which it names: remove sudo_local first) and the firewall
  - app data: Neovim's plugins, Claude Code's plugins and MCP servers (claude mcp remove takes
    blender_official away, as its launcher goes with the links), Claude's skill packs in
    ~/.local/share/claude-skills and their links in ~/.claude/skills, Blender's MCP add-ons and its
    online access, VSCodium's extensions
  - LM Studio's models and engines in ~/.lmstudio
  - the Unity CLI in ~/.unity (unity self-uninstall removes it), and Unity's editors and settings
  - your git identity in ~/.config/git/local and your SSH key
NOTES
}
