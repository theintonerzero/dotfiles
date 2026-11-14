# Ubuntu Server support: design

Date: 2026-11-14. Status: approved by Jesse.

## Intent

A headless Ubuntu server that Jesse logs in to over SSH should feel like Jesse's Fedora and macOS
machines the moment they log in: the same prompt, history search, aliases, tmux and Neovim.
`dot install` on a fresh Ubuntu Server gives that, and nothing else.

What a particular server is for, and how it is locked down, is not this repo's business: that belongs
with the server, somewhere private. This repo is public and says how a machine feels to Jesse. That
goes for this document too: it names no provider, host, domain or service.

## Goals

- `install.sh`, `update.sh` and `uninstall.sh` work on Ubuntu Server, as they do on Fedora and macOS,
  from an `ubuntu/` folder beside `fedora/` and `macos/`.
- A fresh server, after `sudo apt-get install -y git`, a clone over https and `install.sh`, has: zsh as
  the login shell with the same prompt, plugins, aliases and functions; atuin, zoxide, fzf, eza, bat,
  fd, ripgrep, btop; tmux with sesh; git with delta and lazygit; Neovim with Jesse's AstroNvim config
  in a server-sized form; and `dot` on the PATH.
- Works on Ubuntu Server 24.04 LTS and 26.04 LTS, on arm64 and amd64.
- A second `install.sh` run does nothing. `dot update` brings the tools up to date.
- Fedora and macOS behave exactly as they do now.

## Non-goals

- Hardening, a firewall, automatic updates, containers, and whatever a server hosts: those belong
  with the server, outside this repo.
- Naming the computer. See "Calls made".
- Ubuntu Desktop. Nothing here sets up GNOME or installs apps. (The shell setup would work there, but
  it isn't tested or promised.)
- Language toolchains (mise, rustup, uv, .NET), Claude Code, VSCodium, Godot, Unity, Blender, LM Studio,
  Firefox. Jesse chose a lean server.
- Committing from the server. See "Git" below.

## Anti-goals

- Anything personal or server-specific in this repo, its documents, comments, tests and commit
  messages included: no provider, IP address, host name, domain, port, service name or key. The repo
  is public, and what is pushed stays in its history.
- A GitHub sign-in, token or push-capable key on the server.
- Third-party package sources (PPAs, extra apt repos, snap, Homebrew) on the server.
- A change in what Fedora or macOS install, link or set.

## Constraints

- Ubuntu 24.04's packages are too old for the shared config: Neovim 0.9.5 (AstroNvim v6 needs 0.11),
  fzf 0.44 (`.zshrc` runs `fzf --zsh`, which needs 0.48), tree-sitter-cli 0.20 (nvim-treesitter needs
  0.25), and no starship, atuin or lazygit at all. Ubuntu 26.04 has all of them, current: Neovim
  0.11.6, fzf 0.67, tree-sitter-cli 0.25.9, starship 1.22, atuin 18.8, lazygit 0.57. (Read from
  `apt-cache policy` in both images on 2026-11-14.) sesh is in neither.
- Debian's names: `bat` is installed as `batcat` and `fd` as `fdfind`.
- Install runs as a normal user with sudo, never as root. Cloud images often give their default user
  passwordless sudo; a password prompt must work too.
- The repo's own conventions hold: list files with `#` comments, idempotent steps, `say`/`warn`/`todo`,
  plain lowercase comments, tests first, shellcheck-clean, conventional commits.

## Approaches

How the server gets tools Ubuntu's packages lack or have too old:

1. **Ubuntu's package when it is new enough, the project's official release otherwise** (chosen). Each
   such tool has a minimum version. On 26.04 everything but sesh comes from apt, so Ubuntu's own
   security updates cover it; on 24.04 six tools come as release downloads into `~/.local`. It is the
   pattern Fedora already uses for what dnf lacks, and adds no package source.
2. **Always the official release.** One code path and the same versions on every Ubuntu, but on 26.04
   it ignores good, maintained packages and leaves six binaries for `dot update` alone to keep current.
3. **Homebrew on Linux, or mise as a tool installer.** One list shared with macOS, but it puts a large,
   user-writable package manager on a public server, and mise would pull in the shared toolchain config.

Jesse left the how to me; 1 is my call.

## Decided with Jesse

| Question | Answer |
| --- | --- |
| What the server gets | Shell, git, tmux, Neovim. No toolchains, no Claude Code |
| Neovim | Jesse's AstroNvim config, with only the language packs a server needs |
| Git | Pull only: no GitHub sign-in or key on the server |
| Where server-specific setup lives | Outside this repo, in a private one |
| Ubuntu version | Whichever LTS the server is given: 24.04 or 26.04 |
| What may be said here | Nothing personal or server-specific, as the repo is public |

## The design

### Layout

- `ubuntu/steps.sh` defines `os_install`, `os_update`, `os_uninstall`, `os_uninstall_notes`, like the
  other two.
- `ubuntu/packages.txt`: apt packages. `ubuntu/tools.txt`: the tools that may need a release download,
  each with its apt package, minimum version, GitHub repo and asset names for arm64 and amd64.
- `ubuntu/home/`: config only Ubuntu links.

### What install does, in order

1. Asks nothing: no computer name, no GitHub sign-in.
2. apt: updates the package lists when they are more than a day old, then installs what
   `packages.txt` lists that is missing, without recommended extras.
3. Tools: for each line of `tools.txt`, Ubuntu's package if its candidate version meets the minimum,
   else the latest official release for this architecture, into `~/.local` with the command in
   `~/.local/bin`. A release's published checksum is checked when the project publishes one.
4. `bat` and `fd` by those names, as links in `~/.local/bin` to `batcat` and `fdfind`.
5. Ghostty's terminal description (`xterm-ghostty`), compiled into `~/.terminfo` from a source file
   kept in the repo, so tmux and Neovim work over SSH from Ghostty.
6. Links the config (below), makes zsh the login shell, installs fzf-tab, imports history into atuin,
   sets btop's colours: the shared shell step, unchanged.
7. Neovim's plugins and its server-sized set of tools.

`dot update` pulls the repo, upgrades apt's packages, refreshes release-installed tools whose latest
tag differs, relinks, and updates fzf-tab and Neovim's plugins and tools. It leaves a todo when Ubuntu
says a reboot is needed; it never reboots.

`dot uninstall` removes the links and restores `.bak` files, and says what stays.

### Which config is linked

Only the shared packages a server uses: zsh, git, tmux, nvim, starship, and the cli package (lazygit,
bat, atuin, fzf) with `dot`. Not unity, godot, ghostty, claude or mise. An OS can now say which of
`home/`'s packages it links; with no such list, as on Fedora and macOS, it links them all.

### Neovim on the server

The same config, theme and keys. A file only Ubuntu links tells the config it is on a server, so every
way of starting Neovim agrees, headless runs included; it is not an environment variable.

On a server the config loads: Kanagawa, treesitter highlighting, surround, grug-far, trouble, diffview,
render-markdown, and the language packs for Lua, shell, JSON, YAML, TOML and Markdown. It leaves out
Copilot, claudecode.nvim, Discord presence, markdown-preview, neotest, the debugger and overseer, and
the packs for Godot, Python, Rust, Go, C++, C#, Java, Kotlin, Zig, TypeScript and HTML/CSS.

Mason installs only tools that ship as a standalone binary for the machine's architecture. Known
consequence: the shell, JSON and YAML language servers are Node programs, so those three get
highlighting, and shell gets shellcheck and shfmt, but no language-server completion. Lua, TOML and
Markdown keep theirs. Installing Node to change that is a non-goal.

Treesitter compiles its parsers, so `gcc` is one of the apt packages.

### Git

The shared git config is linked: delta, the aliases, the sort and rebase settings. No identity file is
written and no signing key is made, so `git pull`, `clone`, `log` and `diff` work and `git commit`
refuses, which is intended. gh is not installed. A clone of a public repo over https needs no sign-in;
how a server reads a private repo is that server's own setup, not this repo's.

### Calls made (mine, not Jesse's)

- Approach 1 above.
- `gcc` on the server, for treesitter's parsers. Without it Neovim has no syntax highlighting.
- No language-server completion for shell, JSON and YAML on the server, rather than Node.
- `dot update` upgrades apt's packages, as it upgrades dnf's on Fedora, and never reboots.
- Release downloads go in `~/.local`, owned by the user, as on Fedora; nothing is installed system-wide
  outside apt.
- Install refuses to run as root.
- Install doesn't ask for or set the computer's name on Ubuntu. On a cloud image cloud-init owns the
  name and `/etc/hosts`, so making a new name stick means system-wide config, which is the server's
  own setup; `hostnamectl` alone can leave sudo warning that it can't resolve the host.

## Testing

- Sandbox tests in `tests/`, as for the other two: the step order, which packages are linked and which
  aren't, the apt-or-release choice on each side of a minimum version, asset names for both
  architectures, the `bat`/`fd` links, and that Fedora's and macOS's links are unchanged.
- A real run in containers on this Mac with Podman, which is arm64: `ubuntu:24.04` and
  `ubuntu:26.04`, as a non-root user with sudo. In each: install runs clean, a second run does nothing,
  a login zsh starts with no errors and finds every tool, Neovim starts headless with no errors and has
  its parsers and tools, `dot update` and `dot uninstall` work.
- amd64 is covered by the sandbox tests for asset names only, unless an amd64 container runs at a
  usable speed under emulation.
- A real server is the last check.

## Left to the builder

- The file formats of `tools.txt` and the "which shared packages" list.
- How the Neovim config reads the server marker, and how the pack and Mason lists are split.
- Which Mason tools have standalone arm64 and amd64 builds; any that don't are left out and named in
  the README.
- Where under `~/.local` a multi-file release (Neovim) is unpacked.
- README and CHANGELOG wording; the README's Ubuntu row moves to "Done" only after the container runs.
