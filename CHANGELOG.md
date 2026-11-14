# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Location services and automatic problem reports are off, and Coverflow Alt-Tab has a white
  background.
- Steam's "GPU accelerated rendering in web views" (Interface > Advanced) is off. Like Steam's other
  settings, it's set while Steam is closed.
- LM Studio, the newest release from lmstudio.ai, in `~/.local/opt/lm-studio`, with a launcher in
  the Development folder and `lms` on the PATH. It starts in Developer Mode, shows its resource
  monitor and moves deleted chats to the trash; `shared/lmstudio-settings.json` holds these, set
  while LM Studio is closed. `dot update` installs new releases, unless LM Studio has updated itself
  already. No models are downloaded.
- On AMD GPUs, Fedora's ROCm, for LLMs and other GPU compute, and LM Studio's ROCm engine beside its
  Vulkan one, which stays the default. `fedora/rocm.txt` lists the packages, and `dot update` keeps
  them current.
- Claude Code compacts a conversation at about 467,000 tokens, a 500,000-token window less room for
  its reply, instead of near Opus's full 1,000,000. Every call re-reads the conversation, so this
  uses about a third less of the plan.
- Claude Code sends no error reports, shows no session survey, and leaves out the Zoom, ZoomInfo and
  browser-use plugins that claude.ai syncs to it.
- Alt+S is Claude Code's Send now, as Ghostty keeps Ctrl+Enter for fullscreen.
- Claude Code runs shellcheck on each shell script it edits in this repo.
- Unity Hub, from Unity's dnf repo, in the Development folder. Its Unity CLI button opens Ghostty,
  as an `x-terminal-emulator` in `~/.local/bin` hands apps that look for one to the default
  terminal.
- The Unity CLI, from Unity's installer, in `~/.local/bin`, with Unity's usage analytics turned
  off (shared with the Hub, and checked again on each install and update), and no usage pings, crash
  reports, plugin tips or update check of its own; `dot update` updates it. No Unity Editor is
  installed: pick one in the Hub or with `unity install`.
- Claude Code's Unity MCP server (`unity mcp`, from the Unity CLI), and Unity's official plugin and
  Microsoft's docs plugin, for Unity and C#.
- `unity-project`, run in a Unity project or given its path, adds Unity's Pipeline package, which
  the CLI and Claude drive the Editor through, and the Neovim IDE package (`com.walcht.ide.neovim`,
  at a fixed commit), which opens scripts in Neovim and writes the `.sln` and `.csproj` files
  `csharp-ls` reads, and sets the project's Editor and Linux builds to Vulkan alone, in place of
  Unity's automatic OpenGL.
  A settings file it can't read leaves a todo to set Vulkan in the Editor.
- Unity opens scripts in Neovim, in Ghostty, with nothing to pick in its preferences: Neovim is its
  script editor, and the Neovim package opens it through `x-terminal-emulator`, as the package's
  own Ghostty command never starts. Both are set in Unity's preferences while Unity is closed,
  which install starts as an empty file before Unity's first run; an editor or terminal you chose
  yourself stays, and `dot uninstall` gives Unity its own script editor back. The Activate Window By
  Title extension, from extensions.gnome.org, lets the package bring Neovim forward.
- A `unity-workflow` skill for Claude, which it loads for any Unity work, before Unity's own: use
  the installed Editor, run `unity-project` in every project, check games in Play mode with the
  Editor kept ticking, simulated input and Game view captures, and build for Linux from the open
  Editor.
- The cc-blender-skill pack's 30 Blender skills for Claude (modelling, materials, lighting,
  rendering, animation, export, reference-to-3D), linked into `~/.claude/skills` from a clone at a
  fixed commit in `~/.local/share/claude-skills`. `shared/claude-skills.txt` lists skill packs, and
  a skill of your own by the same name stays. Fedora's OpenCV, NumPy, SciPy and Pillow for Python
  run the pack's image scripts.
- Blender Lab's official MCP add-on, from the Blender Lab extensions repo, on Blender 5.1 and newer:
  turned on and started with Blender, on port 9877 beside MCP for Blender's 9876, with Blender's
  online access on, which the add-on needs. Claude's `blender_official` server runs the matching
  release through `blender-lab-mcp`, which looks the release's commit up once, so the server starts
  offline too. `dot update` updates Blender's extensions, this add-on included, while Blender is
  closed, and an add-on turned off in Blender is turned back on.
- Install lists signing in to Unity and installing an Editor among what's left for you, until both
  are done.
- Unity Hub and VSCodium install on their own, so one of their repos being down leaves a todo
  instead of stopping the install, and Unity Hub's repo file is rewritten when it differs from the
  one here.
- Git keeps HTTPS passwords and tokens for hosts such as GitLab in GNOME's keyring, through
  `git-credential-libsecret`. GitHub and its gists sign in through `gh` alone, now set in the linked
  git config, so a token never lands in the keyring even before `gh auth setup-git` has run; Unity
  Hub's GitHub sign-in uses `gh`'s too.

- macOS support, for Apple Silicon Macs on macOS 27: `dot install`, `dot update` and `dot uninstall`
  work there as on Fedora, from a `macos/` folder beside `fedora/`. Homebrew is installed if it's
  missing, and installs what `macos/formulae.txt` and `macos/casks.txt` list: the same shell, git,
  toolchains, Neovim and apps as Fedora, without Steam and the gaming tools. Xcode comes from the
  App Store (`macos/appstore.txt`) once you're signed in there, with its licence accepted, and
  GarageBand, iMovie, Keynote, Numbers and Pages are removed (`macos/remove.txt`). Install starts
  from the bash 3.2 macOS ships and hands itself to Homebrew's.
- macOS's settings, in `macos/defaults.txt`, set by `dot install` where they differ and left alone
  by `dot update`: dark mode, a Dock that hides, at 48px, with no recent apps, no hot corners,
  Finder in list view with the path bar, status bar, hidden files and every extension showing, the
  fastest key repeat with held keys repeating, nothing you type changed for you, tap to click, no
  mouse acceleration, screenshots in `~/Pictures/Screenshots`, and save dialogs opened in full. The
  Dock's apps come from `macos/dock.txt`, and High Power mode and an always-on display on the
  charger from `macos/power.txt`.
- On macOS, Touch ID answers sudo, inside tmux too, the firewall is on, FileVault being off is listed
  as left for you, and no analytics go to Apple. Firefox has the policies it has on Fedora, and is
  made the default browser, which macOS has you confirm.
- On macOS, apps started from the Dock find the shell's tools, through a launch agent that hands
  them `~/.zshenv`'s PATH. Ghostty takes Option as Alt and blurs its see-through background. Godot
  opens scripts in Neovim in a new Ghostty window, as on Fedora, and Unity opens them in VSCodium,
  as its Neovim package doesn't support macOS yet. ArtCraft Launcher comes from its dmg.
- `tests/run.sh`, which runs the steps in a temp home folder with stand-ins for the system's
  commands, so it changes nothing on the machine it runs on.

### Changed

- Claude Code asks before `rm -rf` however its flags are written (`-rf`, `-fr`, `-Rf`, `-fR`), and
  still before force-pushing or deleting a GitHub repo, and before the Unity CLI uninstalls an
  Editor or itself (`unity u` included), installs an Editor or modules (`unity i` and `unity im`
  included), accepts an Editor's terms, closes an Editor (which doesn't save), prunes Editors,
  returns a licence or sends a bug report. It no longer has to ask before Godot's MCP tools run
  code, call methods or write scripts.
- Config packages only one OS uses live in `fedora/home/` or `macos/home/`, and `home/` is linked on
  both. The GTK window-button CSS, the gaming files, the default-terminal list with
  `x-terminal-emulator`, and the `environment.d` file moved to `fedora/home/`. A home linked by the
  older layout relinks itself: the next `dot update` starts again once after pulling, as any update
  that pulls new commits now does, and removes the links the move left pointing nowhere.
- Firefox's policies are in `shared/firefox-policies.json` and VSCodium's settings in
  `shared/vscodium-settings.json`, each linked or applied where the OS's app reads it.
- Git reads where HTTPS logins are kept from `~/.config/git/credential`, a file per OS: GNOME's
  keyring on Fedora, the Keychain on macOS.
- What Claude is told about the machine it's on is a file per OS, `~/.claude/machine.md`, which
  `CLAUDE.md` reads.

- Firefox is hardened further, on Fedora and macOS alike: tracking protection on Strict, DNS over
  HTTPS with the system's DNS to fall back on, DuckDuckGo as the default search engine, no search
  suggestions, no prompts for notifications or your location (a site can still be allowed), the
  Global Privacy Control signal, other sites told only the site you came from, no connections before
  you click, lookalike domain names in their raw form, no scripts in PDFs, and no experiments from
  Mozilla between updates. uBlock Origin also strips tracking parameters from links and hides cookie
  banners; its lists are the policy's now, set again each time Firefox starts, so change them in
  `shared/firefox-policies.json`. Firefox's password manager, and its saving of cards and addresses,
  are off: logins already saved stay in the profile but can't be reached while it's off, so export
  them from `about:logins` before running `dot install`. The last session, WebGL, DRM video, Safe
  Browsing and Sync are as they were.

## [1.2.0] - 2026-10-31

### Added

- Firefox gets uBlock Origin, HTTPS-only mode, and no sponsored shortcuts, stories or suggestions,
  telemetry, studies, feature pop-ups or AI features (translations stay). They're policies in
  `/etc/firefox/policies/policies.json`, from `fedora/firefox-policies.json`; telemetry and studies
  stay off, and the rest can be changed in Firefox.
- Firefox opens Firefox Home in place of Fedora's start page, restores the last session, and drops
  Fedora's shortcut from the new tab page. Fedora's bookmarks, tags and folders are removed from
  profiles that have them, as install's GitHub sign-in opens Firefox first; bookmarks you added
  stay, and the database is kept as `places.sqlite.bak`. Firefox has to be closed for that.
- Steam uses Proton-GE Latest for every game, and shows its performance monitor in full detail at
  the top left, for each account signed in. Steam has to be closed, as it writes its settings when
  it quits.

### Changed

- Install no longer asks you to make Proton-GE Steam's default yourself.
- Ptyxis, Fedora's terminal, is removed, as Ghostty replaces it.

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

[1.2.0]: https://github.com/theintonerzero/dotfiles/releases/tag/v1.2.0
[1.1.0]: https://github.com/theintonerzero/dotfiles/releases/tag/v1.1.0
[1.0.1]: https://github.com/theintonerzero/dotfiles/releases/tag/v1.0.1
[1.0.0]: https://github.com/theintonerzero/dotfiles/releases/tag/v1.0.0
