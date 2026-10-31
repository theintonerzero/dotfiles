# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Firefox gets uBlock Origin, HTTPS-only mode, and no sponsored shortcuts, stories or suggestions,
  telemetry, studies, feature pop-ups or AI features (translations stay). They're policies in
  `/etc/firefox/policies/policies.json`, from `fedora/firefox-policies.json`; telemetry and studies
  stay off, and the rest can be changed in Firefox.
- Firefox opens Firefox Home in place of Fedora's start page, restores the last session, and drops
  Fedora's shortcut from the new tab page. Fedora's bookmarks, tags and folders are removed from
  profiles that have them, as install's GitHub sign-in opens Firefox first; bookmarks you added
  stay, and the database is kept as `places.sqlite.bak`. Firefox has to be closed for that.

## [1.1.0] - 2026-10-31

### Added

- The app grid fits on one page: Settings, then System, Media, Development, Create and Games
  folders that replace Fedora's own; Steam games join Games as they're installed. Edit the folders
  and their order in `fedora/app-folders.txt`.
- Blur my Shell blurs app windows in the overview too.

### Changed

- Fedora Media Writer, Clocks, Camera, Characters, Parental Controls, Calculator and Calendar are
  removed with the other unused apps.

### Fixed

- LibreOffice is removed: unoconv needed it, so it was kept. unoconv now goes with it.

## [1.0.1] - 2026-10-30

### Fixed

- Install no longer seems to freeze after the git step: dnf's checks ran as you, with their output
  hidden, so they downloaded every repo's metadata into a cache of their own and could wait on a
  question no one could see. They now run as root, read the system's cache and never wait for input.

## [1.0.0] - 2026-10-30

First release, for Fedora 44 Workstation with GNOME.

### Added

- `dot install`, `dot update` and `dot uninstall`. GNU Stow links `home/` into `~`, and any file in
  the way is kept as `.bak`.
- One GitHub sign-in through `gh` sets up git's name and email from your profile, an SSH key on
  GitHub for login and signing, and Claude's GitHub MCP server, with no token to make. Install asks
  only for the computer's name.
- System: RPM Fusion with FFmpeg, the multimedia group and its Mesa drivers; COPRs, VSCodium's repo
  and Flathub; Fedora's unused apps removed; a snapper snapshot of `/` before each `dot update`.
- Apps: Steam, Vesktop, Godot, VSCodium, Blender, Spotify (on X11), OBS Studio, Mission Center with
  nethogs and lm_sensors, ArtCraft Launcher and the JetBrains Mono Nerd Font; Firefox with
  middle-click paste off.
- GNOME: settings, Super+Enter for Ghostty, Ctrl+Alt+Del for Mission Center, Ctrl+Shift+Esc for
  btop, JetBrains Mono as the monospace font, the dock, VRR, the Performance power mode, and macOS's
  red, yellow and green window buttons, Flatpak apps included. Extensions: Dash to Dock, Blur my
  Shell (from extensions.gnome.org, with a stronger blur for app windows), Caffeine, AppIndicator
  and Coverflow Alt-Tab.
- Gaming: Steam game names and icons in GNOME, FSR4 on RDNA 4 GPUs, and Proton-GE through
  ProtonPlus.
- Shell and terminal: zsh with plugins, Starship, atuin, zoxide, fzf, Ghostty, tmux with sesh, new
  windows in the current folder and a status bar of pills at the top, and lazygit.
- Git: delta, SSH commit signing and Git LFS.
- Toolchains: mise (Node, Bun, Go, Java, Kotlin, Zig), rustup, uv, the .NET 10 SDK, and the packages
  Bevy games build against.
- Neovim: AstroNvim v6 with 17 language packs, Copilot, claudecode.nvim and Discord presence.
- Godot: Neovim as Godot's external editor with `gdscript-formatter` on save, and `godot-toolkit` to
  add the Godot MCP Toolkit plugin to a project.
- VSCodium: settings and extensions from Open VSX.
- Claude Code: settings with its own dark theme, plugins, language server plugins, and MCP servers
  for GitHub, Godot, Bevy, Blender, Playwright and REA.
- Kanagawa Dragon in Ghostty, the prompt, Neovim and VSCodium.

[1.1.0]: https://github.com/theintonerzero/dotfiles/releases/tag/v1.1.0
[1.0.1]: https://github.com/theintonerzero/dotfiles/releases/tag/v1.0.1
[1.0.0]: https://github.com/theintonerzero/dotfiles/releases/tag/v1.0.0
