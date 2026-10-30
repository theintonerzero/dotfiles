# dotfiles

One command to set up a fresh machine: apps, desktop, gaming, shell, toolchains, Neovim, VSCodium
and Claude Code.

| OS | Status |
| --- | --- |
| Fedora 44 Workstation (GNOME) | Done |
| Ubuntu Server | Not yet |
| macOS | Not yet |

## Install

```sh
sudo dnf install -y git gh
gh auth login --web --git-protocol https --scopes admin:public_key,admin:ssh_signing_key
gh repo clone theintonerzero/dotfiles ~/dotfiles
~/dotfiles/install.sh
```

Install asks for the computer's name and your sudo password. The rest comes from your GitHub
sign-in:

- git's name and email, from your GitHub profile (the no-reply address if your email is private)
- an SSH key, added to GitHub for login and commit signing
- Claude's GitHub MCP server, signed in through `gh`

It ends with a list of what's left, such as logging out and back in and signing in to Claude,
Copilot, Spotify and Vesktop. Running it again only does what's missing.

## Commands

| Command | Does |
| --- | --- |
| `dot install` | Sets everything up |
| `dot update` | Takes a snapshot of `/`, pulls the repo, then updates packages, Flatpaks, toolchains, Neovim, VSCodium, Claude Code and Proton-GE |
| `dot uninstall` | Removes the links and restores the `.bak` files they replaced |

## What you get

| Area | |
| --- | --- |
| System | RPM Fusion, full multimedia codecs, COPRs, VSCodium's repo, snapper snapshots of `/`; LibreOffice, Fedora Media Writer and unused GNOME apps (Calculator, Calendar, Camera, Characters, Clocks, Parental Controls and more) removed |
| Apps | Firefox with uBlock Origin, HTTPS-only mode and no ads, telemetry or AI features, Steam, Vesktop, Godot, VSCodium, Blender, Spotify, OBS Studio, Mission Center, ArtCraft Launcher, JetBrains Mono Nerd Font |
| GNOME | Super+Enter opens Ghostty, Ctrl+Alt+Del Mission Center, Ctrl+Shift+Esc btop, JetBrains Mono as the monospace font, dark style, slate accent, macOS-style red, yellow and green window buttons on the left, no hot corners, flat mouse, no auto-suspend, Performance mode, VRR, the app grid on one page, Settings then System, Media, Development, Create and Games folders; Dash to Dock, Blur my Shell, Caffeine, AppIndicator, Coverflow Alt-Tab |
| Gaming | Steam games named in GNOME, FSR4 on RDNA 4, Proton-GE, GameMode, Gamescope, ProtonTricks |
| Shell | zsh, Starship, atuin, zoxide, fzf, eza, bat, fd, ripgrep, Ghostty, tmux with sesh and pills, lazygit |
| Git | delta, SSH-signed commits, Git LFS |
| Toolchains | mise (Node, Bun, Go, Java, Kotlin, Zig), rustup, uv, .NET 10, GCC |
| Neovim | AstroNvim v6, 17 language packs, Copilot, claudecode.nvim, Discord presence |
| Godot | Neovim as the external editor, `gdscript-formatter` on save; `godot-toolkit` adds the MCP plugin to a project |
| Claude Code | Settings, plugins, language servers, and MCP servers for GitHub, Godot, Bevy, Blender, Playwright and REA |

`home/claude/.claude/CLAUDE.md` is my own; replace it with yours.

## Changing things

Edit a list, then run `dot install`.

| Add or remove | File |
| --- | --- |
| Package | `fedora/packages.txt` |
| COPR | `fedora/copr.txt` |
| Flatpak | `fedora/flatpaks.txt` |
| App to remove | `fedora/remove.txt` |
| GNOME setting | `fedora/gsettings.txt` |
| GNOME extension | `fedora/extensions.txt` |
| App grid folder or order | `fedora/app-folders.txt` |
| Firefox policy | `fedora/firefox-policies.json` |
| Keyboard shortcut | `fedora/shortcuts.txt` |
| VSCodium extension | `shared/vscodium-extensions.txt` |
| Claude plugin | `shared/claude-plugins.txt` |
| Config file | `home/<app>/`, laid out as in `~` |

## Undoing an update

Each `dot update` takes a snapshot of `/` first. List them with `sudo snapper -c root list`, and
undo everything since one with `sudo snapper -c root undochange <number>..0`.

## Theme

Kanagawa Dragon, set in Ghostty, the Starship palette (tmux's status bar uses it too), Neovim
(`lua/plugins/kanagawa.lua`) and VSCodium. Everything else uses the terminal's colours, except the
window buttons, which use macOS's red, yellow and green (`home/gtk/`).
