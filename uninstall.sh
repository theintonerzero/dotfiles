#!/usr/bin/env bash
# uninstall.sh: removes the links and the files install made; packages and settings stay
set -euo pipefail
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib.sh"

[[ $(os_id) == fedora ]] || die "v1.2.0 supports Fedora only"
load_steps fedora

say "removing the links"
unlink_home
gaming_uninstall
apps_uninstall
neovim_uninstall
godot_uninstall
unity_uninstall
say "done"
cat <<'EOF'

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
EOF
