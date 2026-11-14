# macOS support: design

Date: 2026-11-14. Status: awaiting Jesse's approval. Nothing is built yet.

## Why

Jesse is about to erase this Mac (MacBook Pro, M4 Max, macOS 27.0.1). After the reset, cloning the
dotfiles and running one command should give the same working machine the Fedora setup gives: the
same shell, editor, toolchains, game-development tools, apps and Claude Code setup, with macOS tuned
the way a developer wants it. The work happens now, on this Mac, so it can be tried before the wipe.

The repo is Fedora-only today (`install.sh` stops on anything else). The README already lists macOS
as "Not yet".

## What it is

`dot install`, `dot update` and `dot uninstall` work on macOS as they do on Fedora:

- one run sets everything up, and running it again only does what's missing
- what's installed and set comes from list files you edit, one item a line
- a failed app or download leaves a line under "Left for you" and the run carries on
- `dot update` updates what install installed and leaves your settings as you left them
- `dot uninstall` removes the links and gives apps their own editors back; packages and settings stay

## Goals

1. **Same tools as Fedora**, minus Steam and the gaming step. The mapping is in "What gets installed".
2. **macOS tuned for development**, from a list file, as GNOME is from `fedora/gsettings.txt`. The
   settings are in "System settings".
3. **A fresh Mac needs few steps by hand**: install Homebrew, sign in to GitHub, clone, run
   `install.sh`. The README says exactly which.
4. **Fedora keeps working exactly as it does.** The Fedora machine's next `dot update` needs no
   manual step and leaves no broken links.

## Non-goals

- Steam, Proton, GameMode or anything else from `fedora/gaming.sh`.
- Apps that aren't in the Fedora setup. This Mac's extras (Android Studio, RustRover, Docker, Figma,
  Obsidian, Chrome, Teams, Zoom, Final Cut Pro and the rest) are not coming back through the dotfiles.
- Helper apps for desktop parity: no hotkey tool, Alt-Tab replacement, keep-awake toggle or tiling
  window manager. So there is no global shortcut for Ghostty or btop on macOS, and nothing stands in
  for Caffeine, Coverflow Alt-Tab, Dash to Dock or Blur my Shell.
- The iOS platform, simulators and CocoaPods. Xcode is installed ready to build for the Mac only.
- A snapshot before `dot update`. macOS can take one, but the only way back is a whole-disk restore
  from Recovery that also reverts the home folder, and it expires in about a day.
- Installing macOS updates. `dot update` leaves those to System Settings.
- Backing up or erasing the Mac. Jesse handles both.
- Intel Macs, and Ubuntu Server. The layout shouldn't make Ubuntu harder later.

## Anti-goals

These would make it a failure even if it runs:

- Fedora behaving differently after this lands.
- A run that stops half-way because one app, download or setting failed.
- A setting that needs the terminal to have Full Disk Access. None in the list does; if one turns out
  to, it is dropped or goes under "Left for you".
- `dot update` putting a setting back after Jesse changed it by hand.
- The same "Left for you" line on every run for something that can never be done from a script.
- Anything run on this Mac before Jesse says the backup is done (see "Constraints").

## Constraints

- **No live runs before the backup.** Until Jesse says the backup is finished, work is limited to
  reading this Mac's state and writing files in the repo. Nothing that installs, removes, links or
  changes a setting.
- **Apple Silicon, macOS 27.** Few settings are documented for macOS 27 yet. Each one is tried on
  this Mac; one that doesn't take is dropped, or listed under "Left for you" if it matters.
- **Homebrew is the package manager**, from its main repos only (no third-party taps, which
  Homebrew 6 and later ask to be trusted).
- **The repo's conventions hold**: bash, list files with `#` comments, `say` / `warn` / `todo`,
  every step safe to run again, comments and messages in the plain lowercase voice the files use,
  shellcheck clean (the repo's hook runs it), conventional commits, a CHANGELOG entry.
- **macOS ships bash 3.2**, and the scripts use bash 4 and later. `install.sh` run on a Mac that has
  only Homebrew must still work.

## Decided with Jesse

| Question | Answer |
| --- | --- |
| How close to Fedora | 1:1 on dev and gamedev tools and everything else, without gaming |
| Where the two machines differ today | Fedora's choice wins: VSCodium not VS Code, Vesktop not Discord, mise not fnm or pyenv, no oh-my-zsh |
| Desktop | Stock macOS with its own settings tuned; no helper apps |
| Xcode | Full Xcode as well as the Command Line Tools, ready to build for the Mac; no iOS platform |
| App Store apps | Xcode only |
| Settings baseline | This Mac as it is now, without the yellow accent, plus what's good for developers |
| Accent | One that matches Kanagawa Dragon |
| Caps Lock | Left alone |
| Apple's bundled apps | GarageBand, iMovie, Keynote, Numbers and Pages removed |
| Dock | Fedora's order: Firefox, Vesktop, Godot, VSCodium, Ghostty, Blender, Spotify |
| Hidden files in Finder | Always shown |
| Screenshots | `~/Pictures/Screenshots` |
| Trying it out | On this Mac, live, after Jesse's own backup |
| The settings list below | Read and approved as a whole |
| Unity's script editor on macOS | VSCodium, not Neovim, as the Neovim package's macOS support is unfinished upstream |
| Testing the Unity pieces | Jesse signs in and installs a Unity Editor on this Mac before the wipe |

## Calls made for Jesse

Jesse left these to the design ("whatever you recommend"), or they came up after the discussion.

- **Security:** Touch ID for sudo, working inside tmux too; the firewall on, with signed apps still
  allowed in; a "Left for you" line only when FileVault is off.
- **Typing:** smart quotes, smart dashes, autocorrect, auto-capitalise, the double-space full stop and
  inline predictive text all off.
- **Accent:** Graphite, which matches the palette's grey accent (`#7a8382`) and Fedora's slate, but
  only if the red, yellow and green window buttons keep their colours under it on macOS 27. Jesse
  wrote CSS on Fedora to get those colours, so they win. If Graphite greys them, the accent stays
  the default and only the text-selection highlight is set to the Kanagawa grey. This needs a look
  at the screen, so it's settled with Jesse during the build.
- **.NET 10**, to match Fedora, from Homebrew's `dotnet@10`; Homebrew's main .NET package is now 11.
- **Compilers:** Apple's clang, from the Command Line Tools and Xcode, stands in for `gcc`, `gcc-c++`
  and `make`. Homebrew's GCC isn't installed.
- **Debugger for Claude's reverse-engineering server:** `lldb`, which comes with Xcode, in place of
  `gdb`, which can't debug native programs on Apple Silicon. `rizin` and `binwalk` come from Homebrew.
- **Location services are left alone.** Fedora turns them off, but on a MacBook Find My depends on
  them, and they can't be set from a script anyway. The discussion said this would be a "Left for
  you" line; the design drops it so it isn't a nag on every run. Jesse should confirm.
- **Sharing analytics with Apple** is turned off if a script can do it without Full Disk Access,
  matching Fedora's "no automatic problem reports". If it can't, it's left alone.
- **`dot update` on macOS** upgrades Homebrew's formulae and casks, App Store apps (Xcode), then the
  same shared things as Fedora. Apps that update themselves (Firefox, Ghostty and the like) are left
  to do so.
- **Unity projects still get "Vulkan alone" for their Linux builds** when `unity-project` runs on the
  Mac. It's a setting of the project, shared through git, so the project is the same whichever
  machine set it up. The Mac's own editor uses Metal, untouched.
- **`unity-project` still adds the Neovim package to a project on the Mac**, though the Mac doesn't
  use it. A project carries its packages through git, so one set up on the Mac is then ready for
  Fedora, where Unity would otherwise start Neovim with no terminal. If the package turns out to
  break a project on macOS, where upstream hasn't finished it, the Mac leaves it out instead.
- **The Dock holds the seven apps and nothing else** beside Finder and the Downloads stack; an app in
  the list that isn't installed is skipped.
- **Settings live in a list file of the repo's own** (`macos/defaults.txt`), not in mise's built-in
  macOS settings feature, so they read like `fedora/gsettings.txt` and don't tie the Mac's desktop to
  a toolchain manager.

## What gets installed

Homebrew formulae and casks, from list files in `macos/` (one for formulae, one for casks, one for
App Store apps, one for apps to remove). Names were checked against Homebrew's catalogue on
2026-11-14; the builder checks them again.

| Fedora | macOS |
| --- | --- |
| zsh, zsh-autosuggestions, zsh-syntax-highlighting | macOS's own zsh as the login shell; the two plugins from Homebrew |
| starship, atuin, zoxide, fzf, eza, bat, fd, ripgrep, jq, stow | the same, from Homebrew |
| Ghostty, tmux, btop | `ghostty` cask, tmux, btop |
| git, git-lfs, delta, lazygit, gh | the same |
| git-credential-libsecret | the macOS Keychain helper that git ships with |
| mise, rustup, uv | the same; mise still brings Node, Bun, Go, Java, Kotlin, Zig and sesh |
| dotnet-sdk-10.0 | `dotnet@10` |
| gcc, gcc-c++, make | Command Line Tools and Xcode |
| Bevy's build libraries (X11, ALSA, udev, Wayland) | nothing: Bevy needs only Apple's tools on macOS |
| neovim, tree-sitter-cli, unzip, wl-clipboard | neovim, tree-sitter-cli; unzip and the clipboard are built in |
| VSCodium, Blender, Godot, Unity Hub, OBS Studio | `vscodium`, `blender`, `godot`, `unity-hub`, `obs` casks |
| python3 opencv, numpy, scipy, pillow (for the Blender skills' image scripts) | the same four libraries, for whichever Python those scripts run under |
| Firefox with its policies | `firefox` cask, the same policies |
| Vesktop, Spotify | `vesktop`, `spotify` casks |
| LM Studio | `lm-studio` cask; no ROCm, as Apple's GPU needs no extra engine |
| ArtCraft Launcher | its macOS build if it has one; otherwise left out, with a line in the README |
| JetBrains Mono Nerd Font | `font-jetbrains-mono-nerd-font` cask |
| rizin, gdb, binwalk | rizin, binwalk, and lldb from Xcode |
| Mission Center, nethogs, lm_sensors | Activity Monitor, which is built in |
| GNOME Tweaks, the Extensions app and the GNOME extensions | nothing |
| snapper | nothing |
| Steam, GameMode, Gamescope, ProtonTricks, ProtonPlus, ntsync | nothing |
| RPM Fusion codecs and drivers | nothing: macOS has its own |
| (not on Fedora) | Xcode, from the App Store, with its licence accepted and first-launch setup run |

**Removed:** GarageBand (with its sound library), iMovie, Keynote, Numbers and Pages, from a list
like `fedora/remove.txt`. Delete a line to keep one. If macOS won't let the terminal remove an app,
it becomes a "Left for you" line.

**Xcode** needs Jesse signed in to the App Store first, which a script can't do. If the install
can't get it, the run carries on and says so under "Left for you"; running `dot install` again after
signing in finishes it.

**Everything else the shared steps do** comes along unchanged in what it gives: the SSH key on
GitHub for login and signing, git's identity from the GitHub profile, AstroNvim with its language
tools, VSCodium's extensions, Godot opening scripts in Neovim with `gdscript-formatter` on save and
`godot-toolkit`, the Unity CLI with its analytics off and `unity-project`, LM Studio's settings, and
Claude Code with its settings, plugins, skill packs and MCP servers (GitHub, Godot, Unity, Bevy, both
Blender servers, Playwright, REA with Ghidra).

**One difference: Unity's script editor.** On Fedora it's Neovim in Ghostty, through
`com.walcht.ide.neovim`. That package's README, at the commit the repo pins (its newest), lists
macOS support as still to do, and it has no macOS code for bringing Neovim's window forward. So on
macOS Unity opens scripts in VSCodium, which already has a C# extension in
`shared/vscodium-extensions.txt` (`muhammad-sammy.csharp`). Fedora stays on Neovim.

## System settings

From `macos/defaults.txt`, one setting a line, in the manner of `fedora/gsettings.txt`: `dot install`
sets each one that differs and `dot update` leaves them alone. Finder, the Dock and the menu bar are
restarted only when one of their settings changed. Settings that only take hold at the next login
add one "log out and back in" line.

**Copied from this Mac as it is now**

- Dark mode; desktop icons and widgets hidden; no margins around tiled windows
- Dock: hides itself, 48px icons, no recent apps
- Finder: list view, path bar, every file extension shown, new windows open the home folder, the
  Trash emptied after 30 days
- The fastest key repeat the settings offer (repeat 2, delay 15)
- Tap to click; natural scrolling; mouse acceleration off, at tracking speed 0.6875
- On the charger: High Power mode, and the display never sleeps. On battery: untouched
- The Globe key does nothing
- Firefox as the default browser. macOS asks for one click to confirm, so it's set only when the
  default is something else

**Matching Fedora**

- All four hot corners off
- The Dock's apps, in Fedora's order, from a list file. Set by install when they differ, left alone
  by update, as GNOME's dock is
- The accent (see "Calls made for Jesse")
- The computer's name, asked at the start, set as the computer name, the local network name and the
  hostname
- Firefox's policies, from the same file Fedora uses: uBlock Origin, HTTPS-only mode, the last
  session restored, no telemetry, studies, sponsored content or AI features. Applied through
  Firefox's own settings domain, not by adding a file inside the app, which breaks its signature

**Added for development**

- Finder: hidden files shown, status bar, the full path in the window title, folders first, search
  looks in the current folder, no warning on changing an extension, `~/Library` visible, no
  `.DS_Store` files on network or USB drives
- Keyboard: holding a key repeats it instead of offering accents; the six typing corrections off;
  Tab reaches every control in a dialog
- The Dock appears at once when hidden, with no delay
- Spaces stay in the order they were put in
- Screenshots as PNG in `~/Pictures/Screenshots`, which install makes
- Save and print dialogs open expanded; new documents save to disk, not iCloud
- Touch ID for sudo, through the file Apple keeps across updates (`/etc/pam.d/sudo_local`), and
  working inside tmux
- The firewall on, signed apps allowed
- Homebrew sends no analytics and asks no questions during a run

**Left as macOS has them:** Liquid Glass, window tiling, three-finger drag, the menu bar, Caps Lock,
Stage Manager, Safari.

**Left for you, said once at the end of a run when they apply:** sign in to the App Store (for
Xcode); confirm Firefox as the default browser; log out and back in; FileVault is off; and the lines
Fedora already has (sign in to Claude, Copilot, Spotify, Vesktop and Unity, install a Unity Editor,
open LM Studio once). Each app asks "are you sure you want to open it?" the first time; that is
macOS, and nothing lists it.

## Things that must be true on macOS

The shared steps and the files in `home/` were written on Linux. These are the places they assume
it, found by reading them. How each is solved is the builder's choice; what must be true after is not.

**The scripts**

- `install.sh`, `update.sh` and `uninstall.sh` pick the OS and run that OS's steps, in an order each
  OS sets. Fedora's order and behaviour don't change.
- Run with macOS's bash 3.2, `install.sh` gets itself a modern bash from Homebrew (installing
  Homebrew first if it's missing, which also brings the Command Line Tools) and carries on under it.
- The helpers that use GNU-only commands work on both: `find -printf`, `readlink -f`, `sha256sum`,
  `base64 -w`, `install -D`, `realpath -e`, `sort -V`, `getent`, `usermod`, `hostnamectl`, `setsid`.
  Suggested route: Homebrew's GNU tools on the scripts' PATH on macOS, so the shared code changes
  little, with small OS branches where a command has no GNU twin (the login shell, the hostname).
- Checks for a running app (`pgrep -x godot`, `blender`, `lm-studio`, Unity) find the macOS
  processes, whose names differ.

**The linked files**

- On macOS nothing Linux-only is linked into `~`: not `home/gaming`, `home/gtk`, the
  `environment.d` file, `xdg-terminals.list` or `x-terminal-emulator`.
- macOS-only files have a place to live that Fedora doesn't link.
- VSCodium reads the same one `settings.json` on both, from where each OS's VSCodium looks
  (`~/Library/Application Support/VSCodium/User/` on macOS).
- However packages are split by OS, the Fedora machine's next `dot update` relinks cleanly on its
  own. Moving a package Fedora already has linked strands its old links unless something cleans
  them up, so either don't move those or handle the move.
- `home/claude/.claude/CLAUDE.md` has a "This machine" section that says Fedora, GNOME and dnf. It's
  linked on both machines, so that section has to say the right thing on each (Homebrew on macOS).

**The shell**

- Homebrew's programs are on the PATH, after `~/.local/bin`, mise's shims and cargo, as now.
- The two zsh plugins load from Homebrew's folder; `.zshrc` only looks in `/usr/share` today.
- `oh`, `ffs` and `localhost` open things with macOS's `open`.
- `dotnet@10` isn't linked into Homebrew's `bin`, so `dotnet` is on the PATH and `DOTNET_ROOT` is set.
- Apps started from the Dock (Godot, Unity Hub, VSCodium, Blender) find the same tools as the
  shell: `nvim`, `ghostty`, mise's shims, `~/.local/bin`. On Fedora `environment.d` does this; macOS
  needs its own way.

**Ghostty**

- Option works as Alt, so Alt+S in Claude Code, fzf's Alt+C and tmux's Alt keys behave as on Fedora.
- The see-through background is blurred, which Ghostty does itself on macOS, standing in for Blur my
  Shell. Fedora's Ghostty is unaffected.
- `godot-nvim` opens a new Ghostty window running Neovim. `ghostty +new-window` is a Linux feature,
  so macOS uses whatever Ghostty offers there.
- `godot-nvim` keeps its socket under `XDG_RUNTIME_DIR`, which macOS doesn't set; it and
  `lua/godot.lua` agree on another place.

**Git**

- HTTPS logins for hosts other than GitHub go in the macOS Keychain; GitHub's still go through `gh`
  alone. The linked git config names `libsecret` today, so the helper becomes per-OS.

**Apps**

- Godot's editor settings are under `~/Library/Application Support/Godot/`; `gdscript-formatter`
  comes from its macOS arm64 release.
- Unity opens scripts in VSCodium: a double-click on a script in Unity opens it there, at the right
  line, with C# completion working from the project files Unity writes. Unity keeps its editor
  prefs in a macOS preferences file, not the XML file the Linux code edits, so setting the script
  editor needs a macOS version; like Fedora's, it waits for Unity to be closed, leaves an editor
  Jesse picked alone, and `dot uninstall` gives Unity its own choice back. Whether Unity's own
  Visual Studio Code support recognises VSCodium, or needs pointing at it, is found out with the
  Editor Jesse installs.
- The Neovim-only parts of the Unity step (`x-terminal-emulator`, the Neovim package's terminal
  settings) stay Fedora's.
- Blender's config is under `~/Library/Application Support/Blender/<version>/`, for both MCP add-ons.
- Playwright keeps Chromium under `~/Library/Caches/ms-playwright`.
- LM Studio comes from its cask, so the AppImage, launcher and ROCm code are Fedora's alone; the
  shared settings merge still runs once LM Studio has been opened.
- Rosetta is installed only if something in the list turns out to need it.

## Trying it out

- Each piece is run on this Mac once the backup is done, then run again to see it change nothing.
- The Unity pieces (the CLI, the script editor, `unity-project`, Claude's Unity server) are tried
  here too. They need Jesse to sign in to Unity and install an Editor in the Hub once the install
  has put the Hub on this Mac; the repo was checked with 6000.6.
- This Mac isn't clean (old dotfiles links in `~`, oh-my-zsh, fnm, pyenv, apps already installed),
  so a live run doesn't prove the fresh-machine case. A second, throwaway user account on this Mac
  gives an empty home folder without a VM, and is worth one run before the wipe. Jesse chose live
  testing over a VM; this is a suggestion on top of that, to take or leave.
- Fedora can't be run here. The shared code is kept as it is wherever possible, checked with
  shellcheck, and, where practical, the shared helpers are smoke-tested in a Fedora container. The
  real check is `dot update` on the Fedora machine, which Jesse runs.

## Also changed

- README: macOS marked done; a macOS install block beside Fedora's; "What you get" and "Changing
  things" say which rows belong to which OS, with the new `macos/` list files.
- CHANGELOG: an entry under Unreleased, in the file's voice.
- The "supports Fedora only" messages.

## Left to the builder

- File and function names inside `macos/`, and how the steps are split between files.
- The exact format of the list files, as long as they're one item a line with `#` comments.
- How install, update and uninstall choose their steps per OS.
- How packages in `home/` are split by OS, within the rules above.
- How the Dock's apps and the default browser are set (a small Homebrew tool or macOS's own means).
- How GUI apps get their PATH.
- Which settings need which restart, and the exact `defaults` type of each (macOS stores some whole
  numbers as floats, so a comparison has to allow for it).
- Whether Xcode comes through `mas` or `xcodes`; the design assumes the App Store.
