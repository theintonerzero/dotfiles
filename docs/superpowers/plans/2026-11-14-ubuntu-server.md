# Ubuntu Server Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `dot install`, `dot update` and `dot uninstall` on a headless Ubuntu Server give the shell, git, tmux and Neovim setup of the Fedora and macOS machines, and nothing else.

**Architecture:** An `ubuntu/` folder beside `fedora/` and `macos/` defines the four `os_*` functions. apt installs what Ubuntu packages well; a small table names the tools that are too old or missing on some releases, and each comes from apt when apt's version meets a minimum, else from the project's GitHub release into `~/.local`. Ubuntu links only some of `home/`'s packages, and a file only Ubuntu links puts the shared Neovim config in its server form.

**Tech Stack:** bash 5, apt/dpkg, GNU Stow, curl + jq against GitHub's release API, Neovim with AstroNvim v6, the repo's own `tests/` harness, Podman for container runs.

**Spec:** `docs/superpowers/specs/2026-11-14-ubuntu-server-design.md`

## Global Constraints

- The repo is public: no provider, IP address, host name, domain, port, service name or key in any file, comment, test, document or commit message.
- Fedora and macOS install, link and set exactly what they do now; their existing tests stay green unchanged.
- No third-party package source on Ubuntu: no PPA, extra apt repo, snap or Homebrew. No GitHub sign-in, token or key.
- Works on Ubuntu Server 24.04 and 26.04, arm64 and amd64.
- Install runs as a normal user with sudo; it refuses root.
- A second install run does nothing. Every step is safe to run again.
- Repo conventions: list files with `#` comments read by `list`; `say`/`warn`/`todo`/`die`; plain lowercase comments in the repo's voice; a failing test before each change; shellcheck-clean (`~/.local/share/nvim/mason/bin/shellcheck -x`, run from each file's folder); conventional commits ending with the attribution line.
- Tests run with `bash tests/run.sh [name...]`; a test loads an OS's steps with `load <os>` and stubs commands with `stub <name> '<body>'`.

## Review Focus

1. **A machine upgraded from 24.04 to 26.04:** a tool that came from a release now has a good apt package. The release copy and its link are removed, so Ubuntu's maintained one is what runs. (Task 3)
2. **GitHub's API unreachable or rate-limited:** install carries on, a todo names each tool that didn't install, and the next run tries again. (Task 3)
3. **A download that is cut short or fails its checksum:** nothing is installed or replaced; the version already there keeps working. (Task 3)
4. **An architecture that is neither arm64 nor amd64:** release tools are skipped with one warning each; a wrong binary is never installed. (Task 3)
5. **Install started as root,** as cloud images often log you in: it stops with a clear message before changing anything. (Task 1)

---

### Task 1: The `ubuntu/` steps, and which shared packages an OS links

**Files:**
- Create: `ubuntu/steps.sh`, `ubuntu/home.txt`, `tests/test_ubuntu.sh`
- Modify: `lib.sh` (`packages`), `install.sh`, `fedora/steps.sh`, `macos/steps.sh`, `tests/test_steps.sh`

**Interfaces:**
- Produces: `os_install` runs `not_root keep_sudo system_install tools_install link_home shell_install neovim_install`; `os_update` runs `keep_sudo system_update tools_update link_home shell_update neovim_update`; `os_uninstall` runs `unlink_home neovim_uninstall`; `os_uninstall_notes`. `not_root` dies when `EUID` is 0. `packages <root>`: when `<root>` is `$DOTFILES/home` and `$DOTFILES/$(os_id)/home.txt` exists, only the packages that file lists (via `list`) and that exist; otherwise every folder, as now.
- Produces: an optional `os_signins` function. `install.sh` calls it when the OS defines it, in place of its hard-coded sign-in todo; `fedora/steps.sh` and `macos/steps.sh` define it with today's exact text, so their output is unchanged, and Ubuntu doesn't define it.
- `ubuntu/home.txt` lists: `zsh git tmux nvim starship cli`.

- [ ] **Step 1: Write the failing tests** in `tests/test_ubuntu.sh` and `tests/test_steps.sh`:
  - `order ubuntu os_install` equals `"not_root keep_sudo system_install tools_install link_home shell_install neovim_install "`; update `"keep_sudo system_update tools_update link_home shell_update neovim_update "`; uninstall `"unlink_home neovim_uninstall "` (add `not_root` and `tools_(install|update)` to `order`'s pattern).
  - After `(load ubuntu && link_home)`: `~/.config/zsh/.zshrc`, `~/.config/git/config`, `~/.config/tmux/tmux.conf`, `~/.config/nvim/init.lua`, `~/.config/starship.toml`, `~/.config/lazygit/config.yml` and `~/.local/bin/dot` exist; none of `~/.claude`, `~/.config/ghostty`, `~/.config/mise`, `~/.local/bin/godot-nvim`, `~/.local/bin/unity-project`, `~/.config/gtk-4.0`, `~/Library` exist. `unlink_home` then leaves none of them.
  - `(load ubuntu; not_root 0)` fails and its message contains `not as root`; nothing was called (`calls` is empty). `EUID` is read-only in bash, so `not_root` takes the id as `${1:-$EUID}`.
  - `install.sh` under `DOT_OS=ubuntu` with every step stubbed prints no line containing `Spotify`; under `DOT_OS=fedora` it still prints `sign in to Claude (claude), Copilot (:Copilot auth in Neovim), Spotify and Vesktop`.
  - `DOT_OS=unknown ./install.sh` dies with `these dotfiles support Fedora, macOS and Ubuntu Server`.
  - `os_uninstall_notes` on ubuntu mentions `apt` and `~/.local/opt`.
- [ ] **Step 2: Run** `bash tests/run.sh ubuntu steps` — expected: FAIL (no `ubuntu/steps.sh`).
- [ ] **Step 3: Implement** the files above. `system_install`, `system_update`, `tools_install`, `tools_update` don't exist yet: this task's tests stub them through `order`, and `load ubuntu` must not fail without them.
- [ ] **Step 4: Run** `bash tests/run.sh` — expected: every file `ok`, the Fedora and macOS cases untouched.
- [ ] **Step 5: Commit** `feat(ubuntu): the steps ubuntu server runs, and only the config a server uses`.

### Task 2: apt's packages, Debian's names, and Ghostty's terminal description

**Files:**
- Create: `ubuntu/system.sh`, `ubuntu/packages.txt`, `ubuntu/xterm-ghostty.terminfo`
- Test: `tests/test_ubuntu.sh`

**Interfaces:**
- Produces: `system_install` runs `apt_refresh`, `apt_packages`, `debian_names`, `terminfo_install`. `system_update` runs `apt_refresh force`, `apt_upgrade`, `debian_names`.
- `apt_refresh [force]`: `apt-get update` when `APT_LISTS` (default `/var/lib/apt/lists`) holds no `*_Packages*`/`*InRelease` file newer than a day, or when forced.
- `apt_missing`: the lines of `ubuntu/packages.txt` that `dpkg-query -W -f='${db:Status-Status}' <pkg>` doesn't report as `installed`.
- `apt_packages`: one `DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends <missing...>` through `as_root`; nothing when none is missing.
- `apt_upgrade`: `apt-get upgrade -y` the same way, with `NEEDRESTART_MODE=a`; a todo `restart the computer: Ubuntu says an update needs it` when `REBOOT_FLAG` (default `/var/run/reboot-required`) exists.
- `debian_names`: `~/.local/bin/bat` → `batcat` and `~/.local/bin/fd` → `fdfind`, each only when the Debian-named command exists and the plain name isn't already found outside `~/.local/bin`.
- `terminfo_install`: when `infocmp xterm-ghostty` fails, `tic -x -o ~/.terminfo ubuntu/xterm-ghostty.terminfo`.
- `ubuntu/packages.txt`: `zsh zsh-autosuggestions zsh-syntax-highlighting stow jq curl ca-certificates unzip git git-delta eza bat fd-find ripgrep zoxide tmux btop gcc libc6-dev`, grouped under comments as the other lists are; the `gcc` comment says it is for Neovim's treesitter parsers.
- `ubuntu/xterm-ghostty.terminfo`: the output of `infocmp -x xterm-ghostty` from Ghostty's own terminfo (`/Applications/Ghostty.app/Contents/Resources/terminfo`), with a first-line comment saying where it came from.

- [ ] **Step 1: Write the failing tests:** with a `dpkg-query` stub that reports only `zsh` installed, `apt_packages` makes exactly one `sudo` call containing `apt-get install -y --no-install-recommends` and every other listed package, and not `zsh`; with all installed, no `apt-get install` call. `apt_refresh` with an empty `APT_LISTS` calls `apt-get update`; with a fresh `x_InRelease` file there, it doesn't; `apt_refresh force` does. `debian_names` with stub `batcat` and `fdfind` makes both links, a second run changes nothing, and with neither command present makes neither. `apt_upgrade` with `REBOOT_FLAG` pointing at an existing file leaves the restart todo. `terminfo_install` with an `infocmp` stub that fails calls `tic -x -o $HOME/.terminfo`, and with one that succeeds calls no `tic`. Every listed package name matches `^[a-z0-9][a-z0-9.+-]+$`.
- [ ] **Step 2: Run** `bash tests/run.sh ubuntu` — expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `bash tests/run.sh` — expected: all `ok`.
- [ ] **Step 5: Commit** `feat(ubuntu): apt's packages, bat and fd by their names, and ghostty's terminfo`.

### Task 3: Tools from apt when it is new enough, else from the project's release

**Files:**
- Create: `ubuntu/tools.sh`, `ubuntu/tools.txt`
- Test: `tests/test_ubuntu.sh`

**Interfaces:**
- `ubuntu/tools.txt`, one tool a line, fields split on whitespace: `command  apt-package  minimum  owner/repo  arm64-asset-regex  amd64-asset-regex`; `-` for no apt package. The lines:

  | command | apt package | minimum | repo |
  | --- | --- | --- | --- |
  | `nvim` | `neovim` | `0.11.0` | `neovim/neovim` |
  | `tree-sitter` | `tree-sitter-cli` | `0.25.0` | `tree-sitter/tree-sitter` |
  | `fzf` | `fzf` | `0.48.0` | `junegunn/fzf` |
  | `starship` | `starship` | `1.0.0` | `starship/starship` |
  | `atuin` | `atuin` | `18.0.0` | `atuinsh/atuin` |
  | `lazygit` | `lazygit` | `0.40.0` | `jesseduffield/lazygit` |
  | `sesh` | `-` | `-` | `joshmedeski/sesh` |

  The two asset regexes for each are written from the names the project's latest release really has, read from GitHub's API at implementation time, for a gzip or tar.gz build for Linux on each architecture; static (musl) builds where a project offers both.
- `version_ge <have> <want>`: true when Debian version `<have>`, with its epoch, `+`/`~` suffix and `-revision` stripped, sorts at or after `<want>` (pure bash plus `sort -V`, so it tests on macOS).
- `apt_candidate <pkg>`: the candidate version from `apt-cache policy`, or nothing.
- `tool_arch`: `arm64` for `aarch64`/`arm64`, `amd64` for `x86_64`/`amd64`, nothing otherwise, from `uname -m`.
- `tools_install` / `tools_update`: for each line, `tool_apt <cmd> <pkg>` when `apt_candidate` meets the minimum (installs the package if missing, and removes `~/.local/opt/<cmd>` and the `~/.local/bin/<cmd>` link that points into it), else `tool_release <cmd> <repo> <regex>`. A tool that fails leaves a todo `<cmd> didn't install; dot install tries again` and the loop goes on.
- `tool_release <cmd> <repo> <regex>`: the latest release's matching asset, unpacked into `~/.local/opt/<cmd>/` with its tag written to `~/.local/opt/<cmd>/.release`, and `~/.local/bin/<cmd>` linked to the executable named `<cmd>` found inside. Nothing happens when `.release` already holds the latest tag. The new copy is unpacked beside the old one and swapped in only once complete and verified.
- `release_verify <release json> <asset name> <file>`: 0 when the release publishes a checksum for the asset (an asset named `<asset>.sha256` or `<asset>.sha256sum`, or a checksums file listing the asset's name) and the file matches, or when it publishes none; 1 on a mismatch.

- [ ] **Step 1: Read each project's latest release** (`curl -fsSL https://api.github.com/repos/<repo>/releases/latest | jq -r '.assets[].name'`) and write the fourteen regexes into `tools.txt`, plus a note in the file's header of which projects publish no checksum.
- [ ] **Step 2: Write the failing tests:**
  - `version_ge`: `0.11.6-1` ≥ `0.11.0`; `0.9.5-6ubuntu2` not ≥ `0.11.0`; `1:2.53.0-1ubuntu1` ≥ `2.40.0`; `0.57.0+ds1-1` ≥ `0.40.0`; `0.44.1-1ubuntu0.3` not ≥ `0.48.0`; `0.48.0-1` ≥ `0.48.0`.
  - `tool_arch` under a `uname` stub: `aarch64` → `arm64`, `x86_64` → `amd64`, `riscv64` → empty.
  - Every `tools.txt` line has six fields, and each regex is anchored `^…$` and compiles in `jq`.
  - With `apt-cache` reporting `neovim` candidate `0.11.6-1`: `apt-get install … neovim` is called, no `curl`. With `0.9.5-6ubuntu2`: no `apt-get install neovim`, and a stubbed release (a tar.gz built in the test holding `nvim-linux-arm64/bin/nvim`) ends as an executable `~/.local/bin/nvim` whose target is under `~/.local/opt/nvim/`, with `.release` holding the tag; a second run downloads nothing.
  - Review Focus 1: with that release copy in place and the candidate now `0.11.6-1`, `~/.local/opt/nvim` and the link are gone and the apt install is called.
  - Review Focus 2: with a `curl` stub that fails, `tools_install` returns 0, `TODOS` names every release tool, and no `~/.local/opt/*` exists.
  - Review Focus 3: with a release whose checksum asset doesn't match, the existing `~/.local/opt/nvim/.release` and binary are unchanged and a todo is left; the same when the tar.gz is truncated.
  - Review Focus 4: under `uname` → `riscv64`, no `curl` download is made for any tool and each leaves one warning.
  - A single-file `.gz` asset (tree-sitter's shape) installs as an executable named `tree-sitter`.
- [ ] **Step 3: Run** `bash tests/run.sh ubuntu` — expected: FAIL.
- [ ] **Step 4: Implement.**
- [ ] **Step 5: Run** `bash tests/run.sh` — expected: all `ok`.
- [ ] **Step 6: Commit** `feat(ubuntu): each tool from apt when it's new enough, or from its own release`.

### Task 4: Neovim in its server form

**Files:**
- Create: `home/nvim/.config/nvim/lua/profile.lua`, `ubuntu/home/nvim/.config/nvim/lua/machine.lua`
- Modify: `home/nvim/.config/nvim/lua/community.lua`, `lua/plugins/mason.lua`, `lua/plugins/godot.lua`, `lua/plugins/markdown-preview.lua`
- Test: `tests/test_nvim.sh`

**Interfaces:**
- `machine.lua` (linked on Ubuntu only) returns `{ server = true }`. `profile.lua` returns `{ server = <bool> }`: true only when `require("machine")` succeeds and says so. Everything else asks `require("profile").server`.
- `community.lua` on a server imports only: the packs `lua bash json yaml toml markdown`, and `markdown-and-latex.render-markdown-nvim`, `diagnostics.trouble-nvim`, `git.diffview-nvim`, `search.grug-far-nvim`, `motion.nvim-surround`, `colorscheme.kanagawa-nvim`. Off a server its list is exactly today's, in today's order.
- `mason.lua` on a server: adds none of `pyright`, `typescript-language-server`, `kotlin-lsp`, and after the packs have added theirs, keeps in `ensure_installed` only the names in a `standalone` list in that file: `lua-language-server stylua selene shellcheck shfmt taplo marksman`, less any Step 1 finds has no arm64 or amd64 Linux build. The headless `run_on_start = false` rule stays.
- `godot.lua` and `markdown-preview.lua` return `{}` on a server.

- [ ] **Step 1: Check Mason's registry** for each name in `standalone` (`~/.local/share/nvim/mason/registries/` or the package's `package.yaml` on GitHub): it must have a `linux_arm64` and a `linux_x64` binary source, not an `npm`, `pypi`, `golang` or `cargo` one. Drop any that doesn't and note it for the README.
- [ ] **Step 2: Write the failing tests** (run with this machine's `nvim --headless -l`, skipped when there is no `nvim`): loading `community.lua` with a `machine` module on the path gives exactly the twelve imports above plus `"AstroNvim/astrocommunity"`; without it, the list equals the one in `git show HEAD:home/nvim/.config/nvim/lua/community.lua`. `mason.lua`'s `opts`, given an `ensure_installed` of `{ "lua-language-server", "bash-language-server", "shfmt", "prettierd" }` on a server, returns `{ "lua-language-server", "shfmt" }`; off a server it returns those four plus `pyright`, `typescript-language-server`, `kotlin-lsp`. After `(load ubuntu && link_home)`, `~/.config/nvim/lua/machine.lua` exists; after `load fedora` or `load macos`, it doesn't.
- [ ] **Step 3: Run** `bash tests/run.sh nvim ubuntu` — expected: FAIL.
- [ ] **Step 4: Implement.**
- [ ] **Step 5: Run** `bash tests/run.sh`, then start this Mac's own Neovim headless (`nvim --headless "+lua print(#require('lazy').plugins())" +qa`) — expected: all `ok`, and the plugin count on this Mac unchanged from before the task.
- [ ] **Step 6: Commit** `feat(nvim): a server-sized neovim where a machine says it's a server`.

### Task 5: Real installs in Ubuntu containers

**Files:**
- Create: `tests/container.sh`
- Modify: whatever the runs show to be wrong, each with a test in `tests/test_ubuntu.sh` first

**Interfaces:**
- `tests/container.sh <image>` (default `ubuntu:24.04`): with Podman, starts a container from the image, makes a user with passwordless sudo, installs only `sudo git ca-certificates`, copies the working tree in, and runs as that user: `install.sh`; `install.sh` again; a login `zsh -lic` that prints the versions of `nvim starship atuin fzf lazygit sesh tree-sitter eza bat fd rg zoxide tmux delta` and fails on any stderr line; `nvim --headless "+checkhealth" "+w! /tmp/health" +qa` then greps the file for `ERROR`; `update.sh` with `pull_dotfiles` finding no upstream; `uninstall.sh`. It prints `PASS <image>` or the failing stage, and removes the container. It is not part of `tests/run.sh`.

- [ ] **Step 1: Write `tests/container.sh`.**
- [ ] **Step 2: Run** `tests/container.sh ubuntu:24.04` and `tests/container.sh ubuntu:26.04`. Expected on each: the second install prints no `==>` line; every tool reports a version, on 24.04 `nvim` ≥ 0.11 from `~/.local/opt` and on 26.04 from `/usr/bin`; zsh starts with no error; `checkhealth` has no `ERROR` that isn't about a tool the server leaves out on purpose; after uninstall no link into the repo is left under the user's home.
- [ ] **Step 3: Fix what fails,** test first, and rerun both until `PASS`.
- [ ] **Step 4: Try amd64:** `podman run --rm --arch amd64 ubuntu:24.04 uname -m`. If it runs at a usable speed, run `tests/container.sh` with `--arch amd64` on 24.04 too; if not, say so in the hand-back and leave amd64 to the sandbox tests.
- [ ] **Step 5: Commit** `test(ubuntu): a real install in an ubuntu container`, and any `fix(ubuntu): …` separately.

### Task 6: README, CHANGELOG, and the last checks

**Files:**
- Modify: `README.md`, `CHANGELOG.md`

- [ ] **Step 1: README:** the status row becomes `| Ubuntu Server 24.04 and 26.04 | Done |`; an install block for Ubuntu (`sudo apt-get install -y git`, `git clone https://github.com/theintonerzero/dotfiles ~/dotfiles`, `~/dotfiles/install.sh`), saying it asks nothing and signs in to nothing; one "What you get" row, "On Ubuntu Server", naming what a server gets and what it leaves out, the Neovim limits included; the lists table gains `ubuntu/packages.txt`, `ubuntu/tools.txt` and `ubuntu/home.txt`; the Tests section mentions `tests/container.sh`. `tests/test_steps.sh` gains: the README has the Ubuntu block and no `Not yet` row for it.
- [ ] **Step 2: CHANGELOG:** one Added entry under Unreleased, wrapped at 100.
- [ ] **Step 3: Run** `bash tests/run.sh`, shellcheck over every shell file, both container runs once more, and `git grep` for anything the Global Constraints forbid.
- [ ] **Step 4: Commit** `docs: ubuntu server is done`.

After this plan: a whole-branch review by a fresh reviewer, one fix pass, then a real server.
