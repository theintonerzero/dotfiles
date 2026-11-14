# fedora/steps.sh: the order fedora's steps run in, for install, update and uninstall
# shellcheck shell=bash

os_install() {
  ask_questions
  keep_sudo
  set_hostname
  system_install
  apps_install
  link_home
  shell_install
  git_install
  toolchains_install
  neovim_install
  vscodium_install
  godot_install
  unity_install
  claude_install
  gnome_install
  gaming_install
  llm_install
}

os_update() {
  keep_sudo
  system_update
  apps_update
  link_home
  shell_update
  toolchains_update
  neovim_update
  vscodium_update
  unity_update
  claude_update
  godot_update
  gnome_update
  gaming_update
  llm_update
}

os_uninstall() {
  say "removing the links"
  unlink_home
  gaming_uninstall
  apps_uninstall
  neovim_uninstall
  godot_uninstall
  unity_uninstall
}

# os_signins: what only you can sign in to, said last
os_signins() {
  todo "sign in to Claude (claude), Copilot (:Copilot auth in Neovim), Spotify and Vesktop"
}

# os_uninstall_notes: what uninstall leaves behind, said once it's done
os_uninstall_notes() {
  cat <<'NOTES'

These stay, so remove them yourself if you want them gone:
  - the packages, Flatpaks and repos install added
  - GNOME's settings, extensions and dock
  - app data: Neovim's plugins, Claude Code's plugins and MCP servers (claude mcp remove takes
    blender_official away, as its launcher goes with the links), Claude's skill packs in
    ~/.local/share/claude-skills and their links in ~/.claude/skills, Blender's MCP add-ons and its
    online access, VSCodium's extensions
  - LM Studio and its launcher, in ~/.local/opt/lm-studio, and its models and engines in ~/.lmstudio
  - the Unity CLI in ~/.local/bin (unity self-uninstall removes it), and Unity's editors and settings
  - your git identity in ~/.config/git/local and your SSH key
NOTES
}
