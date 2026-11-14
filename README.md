# dotfiles

One command to set up a fresh machine: apps, desktop, gaming, shell, toolchains, Neovim, VSCodium
and Claude Code.

| OS | Status |
| --- | --- |
| Fedora 44 Workstation (GNOME) | Done |
| macOS 27 (Apple Silicon) | Done |
| Ubuntu Server | Not yet |

## Install

On Fedora:

```sh
sudo dnf install -y git gh
gh auth login --web --git-protocol https --scopes admin:public_key,admin:ssh_signing_key
gh repo clone theintonerzero/dotfiles ~/dotfiles
~/dotfiles/install.sh
```

On macOS, where Homebrew comes first, and brings Apple's Command Line Tools with it:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install gh
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

On macOS, sign in to the App Store before you start, and Xcode installs in the same run; otherwise
it's on the list of what's left, and running install again once you've signed in finishes it.

## Commands

| Command | Does |
| --- | --- |
| `dot install` | Sets everything up |
| `dot update` | Pulls the repo, then updates packages and apps, toolchains, Neovim, VSCodium, the Unity CLI and Claude Code. On Fedora it takes a snapshot of `/` first, and updates Flatpaks, LM Studio and Proton-GE too; on macOS, Homebrew's formulae and casks and the App Store's apps. Your settings stay as you left them |
| `dot uninstall` | Removes the links and restores the `.bak` files they replaced, and gives Godot and Unity their own script editors back |

## What you get

| Area | |
| --- | --- |
| System, on Fedora | RPM Fusion, full multimedia codecs, COPRs, VSCodium's repo, snapper snapshots of `/`; LibreOffice, Fedora Media Writer, Ptyxis and unused GNOME apps (Calculator, Calendar, Camera, Characters, Clocks, Parental Controls and more) removed |
| System, on macOS | Homebrew, installed if it's missing, and its formulae and casks; Xcode from the App Store, with its licence accepted and its first launch run; GarageBand, iMovie, Keynote, Numbers and Pages removed; Touch ID for sudo, inside tmux too; the firewall on; no analytics sent to Apple; `wget` and Podman, which Fedora ships, with Podman's Linux VM made for it (`podman machine start` runs it) |
| Apps | Firefox, hardened: uBlock Origin, with lists for tracking links and cookie banners too, strict tracking protection, HTTPS-only mode, encrypted DNS, DuckDuckGo as the search engine, and no search suggestions, password manager, notification or location prompts, ads, telemetry, experiments or AI features; Firefox Home in place of Fedora's start page, the last session restored, and no Fedora bookmarks. Then Steam, Vesktop, Godot, Unity Hub, VSCodium, Blender, Spotify, OBS Studio, Mission Center, ArtCraft Launcher, JetBrains Mono Nerd Font. On macOS, the same from Homebrew's casks, without Mission Center, with Steam as the client alone, for testing a game's Steamworks, and with Firefox as the default browser |
| GNOME, on Fedora | Super+Enter opens Ghostty, Ctrl+Alt+Del Mission Center, Ctrl+Shift+Esc btop, JetBrains Mono as the monospace font, dark style, slate accent, macOS-style red, yellow and green window buttons on the left, no hot corners, flat mouse, no auto-suspend, Performance mode, VRR, the app grid on one page, Settings then System, Media, Development, Create and Games folders; Dash to Dock, Blur my Shell, Caffeine, AppIndicator, Coverflow Alt-Tab, Activate Window By Title |
| macOS's settings | Dark mode with the Graphite accent; a Dock that hides, at 48px, with no recent apps, holding Firefox, Steam, Vesktop, Godot, VSCodium, Ghostty, Blender and Spotify; no hot corners; Finder in list view with the path bar, status bar, hidden files and every extension showing, folders first; the fastest key repeat, held keys repeating, and nothing you type changed for you; tap to click, no mouse acceleration; screenshots in `~/Pictures/Screenshots`; save dialogs opened in full; High Power mode and an always-on display on the charger |
| Gaming, on Fedora | Steam games named in GNOME, FSR4 on RDNA 4, Proton-GE as Steam's default, Steam's performance monitor in full detail at the top left, no GPU rendering in Steam's web views, GameMode, Gamescope, ProtonTricks |
| Shell | zsh, Starship, atuin, zoxide, fzf, eza, bat, fd, ripgrep, Ghostty, tmux with sesh and pills, lazygit. On macOS, Ghostty takes Option as Alt and blurs its background, Ctrl+Cmd+Enter opens a new Ghostty window from any app while Ghostty is running, as Super+Enter does on Fedora, and apps started from the Dock find the shell's tools |
| Git | delta, SSH-signed commits, the newest branches and tags listed first, rebases that stash your changes, squash fixups and move stacked branches, the diff under the commit message as you write it, a prompt when a command is mistyped, Git LFS, HTTPS logins (GitLab's, say) in GNOME's keyring or macOS's Keychain, and GitHub's through `gh` alone |
| Toolchains | mise (Node, Bun, Go, Java, Kotlin, Zig), rustup, uv, .NET 10, GCC, or Apple's clang on macOS |
| Neovim | AstroNvim v6, 17 language packs, Copilot, claudecode.nvim, Discord presence |
| VSCodium | Kanagawa Dragon, JetBrains Mono, 18 extensions from Open VSX, Unity's snippets among them, and the Vim extension with AstroNvim's keys: Space as the leader (`Space w` saves, `Space e` the explorer, `Space ff` finds files, `Space fw` words, `Space la` code actions, and the rest of its buffer, LSP, git and debugger keys), `jj` or `jk` to leave insert mode, Ctrl+H/J/K/L between splits, the explorer's `a`, `r`, `d`, `h` and `l` as in Neo-tree, the system clipboard, relative line numbers |
| Godot | Neovim as the external editor, `gdscript-formatter` on save; `godot-toolkit` adds the MCP plugin to a project |
| Unity | Unity Hub from Unity's dnf repo, opening its terminal in Ghostty; the Unity CLI with no usage analytics, crash reports, plugin tips or update check; Neovim, in Ghostty, as Unity's script editor, brought forward by Activate Window By Title; `unity-project [path]` adds Unity's Pipeline package, for the CLI and Claude, and the Neovim IDE package, which writes the `.sln` for its C# server, and puts the project on Vulkan. On macOS, Unity Hub comes from Homebrew and Unity's script editor is VSCodium, as the Neovim package doesn't support macOS yet; Unity reaches it through a link with "code" in its path, which is what makes Unity write the project files C# completion reads |
| LLMs | LM Studio in the Development folder, `lms` on the PATH, Developer Mode and its resource monitor, and no models downloaded; on AMD GPUs, Fedora's ROCm, and LM Studio's ROCm engine beside its default Vulkan one. On macOS, LM Studio from Homebrew's cask, with the same settings |
| Claude Code | Settings (compacting at about 467k tokens, Alt+S for Send now, no error reports or surveys), plugins, a `unity-workflow` skill, the cc-blender-skill pack of 30 Blender skills, language servers, and MCP servers for GitHub, Godot, Unity, Bevy, Blender (the community MCP for Blender and Blender Lab's official one), Playwright and REA |

`home/claude/.claude/CLAUDE.md` is my own; replace it with yours.

## Changing things

Edit a list, then run `dot install`.

| Add or remove | File |
| --- | --- |
| Package, on Fedora | `fedora/packages.txt` |
| COPR | `fedora/copr.txt` |
| ROCm package, on AMD GPUs | `fedora/rocm.txt` |
| Flatpak | `fedora/flatpaks.txt` |
| App to remove, on Fedora | `fedora/remove.txt` |
| GNOME setting | `fedora/gsettings.txt` |
| GNOME extension | `fedora/extensions.txt` |
| App grid folder or order | `fedora/app-folders.txt` |
| Keyboard shortcut, on Fedora | `fedora/shortcuts.txt` |
| Homebrew formula | `macos/formulae.txt` |
| Homebrew cask | `macos/casks.txt` |
| App Store app | `macos/appstore.txt` |
| Apple app to remove | `macos/remove.txt` |
| macOS setting | `macos/defaults.txt` |
| Dock app | `macos/dock.txt` |
| Power setting, on macOS | `macos/power.txt` |
| Firefox policy | `shared/firefox-policies.json` |
| VSCodium setting | `shared/vscodium-settings.json` |
| VSCodium extension | `shared/vscodium-extensions.txt` |
| VSCodium key | `shared/vscodium-settings.json` for Vim's, in the editor; `shared/vscodium-keybindings.json` for the explorer, terminal and panels |
| Claude plugin | `shared/claude-plugins.txt` |
| Claude setting | `shared/claude-settings.json` |
| LM Studio setting | `shared/lmstudio-settings.json` |
| Config file | `home/<app>/`, laid out as in `~`; `fedora/home/<app>/` or `macos/home/<app>/` for one that only that OS links |

## Undoing an update

On Fedora, each `dot update` takes a snapshot of `/` first. List them with `sudo snapper -c root
list`, and undo everything since one with `sudo snapper -c root undochange <number>..0`.

## Theme

Kanagawa Dragon, set in Ghostty, the Starship palette (tmux's status bar uses it too), Neovim
(`lua/plugins/kanagawa.lua`) and VSCodium. Everything else uses the terminal's colours, except
Fedora's window buttons, which use macOS's red, yellow and green (`fedora/home/gtk/`).

## Tests

`tests/run.sh` runs the steps in a temp home folder, with stand-ins for the system's commands, so it
changes nothing on the machine it runs on.
