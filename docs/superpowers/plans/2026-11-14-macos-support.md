# macOS Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `dot install`, `dot update` and `dot uninstall` set up a fresh Apple Silicon Mac to match the Fedora setup (minus gaming), with macOS tuned for development, while Fedora keeps working as it does.

**Architecture:** A `macos/` folder beside `fedora/` holds the Mac's steps and list files; each OS names its own step order in `<os>/steps.sh`, and the three entry scripts become OS-neutral. Config packages split into `home/` (every OS) and `<os>/home/` (that OS only). Shared steps get small OS branches through two helpers (`running`, `app_dir`) rather than GNU tools from Homebrew, because a check of this Mac showed only `find -printf` and `realpath -e` are missing.

**Tech Stack:** bash 5 (Homebrew's on macOS, reached from bash 3.2 by a re-exec), GNU Stow, Homebrew formulae and casks, `mas`, `defaults`, `pmset`, `scutil`, `plutil`, `launchctl`, jq, zsh. Tests are plain bash scripts in `tests/`, run in a temp `HOME` with stubbed system commands.

**Spec:** `docs/superpowers/specs/2026-11-14-macos-support-design.md`. Read it first; this plan argues from it.

## Global Constraints

- **Backup gate.** Tasks 1–10 only write files in the repo and run `tests/run.sh`, which works in a temp folder with stubs. Nothing that installs, removes, links into the real `~`, or changes a setting runs before Jesse says the backup is done. Tasks 11–13 are behind that gate.
- **Tests never touch the machine.** Every test runs with `HOME` in a temp folder and stubs first on `PATH`. The `sudo` stub records its arguments and runs nothing.
- **Fedora's behaviour doesn't change.** Its step order, messages and results stay as they are. Its next `dot update` must relink on its own and leave no broken links.
- **Homebrew's main repos only.** No third-party taps.
- **No setting may need Full Disk Access.** One that does is dropped.
- **Nothing fatal.** A failed app, download or setting calls `warn` or `todo` and the run carries on.
- **`dot update` never sets system settings.** Only `dot install` does.
- **Repo conventions:** bash, `set -euo pipefail` in entry scripts only, list files with `#` comments read through `list`, `say`/`warn`/`todo`/`die`, comments and messages in the files' plain lowercase voice, every step safe to run again.
- **Lint:** shellcheck isn't on this Mac's `PATH`; use `~/.local/share/nvim/mason/bin/shellcheck -x <file>` on each shell file a task touches. Expected: no output.
- **Git:** work on a branch named `macos`. Conventional commits (`feat(macos): …`, `refactor: …`, `test: …`, `docs: …`), each ending with `Co-Authored-By: Claude <noreply@anthropic.com>`.
- **Test command:** `bash tests/run.sh` (all) or `bash tests/run.sh links` (one file). Expected on success: a `ok <file>` line per file and exit 0.

## Facts checked on this Mac on 2026-11-14

These were read, not assumed; build on them.

- `/bin/bash` is 3.2.57. `lib.sh`, the entry scripts and every `shared/*.sh` parse under it (`/bin/bash -n`).
- Built in and working: `readlink -f`, `sha256sum`, `base64 -w 0`, `sort -V`, `ln -sfn`, `find -mindepth`. Missing: `find -printf`, `realpath -e`, `getent`, `usermod`, `hostnamectl`, `setsid`, `install -D`.
- `ghostty +new-window` prints "not supported on this platform" on macOS. Ghostty's own help says to use `open -na Ghostty.app --args …`. Its config has `background-blur`, `macos-option-as-alt` and `config-file`.
- Casks: `godot` puts `godot` on the PATH, `vscodium` puts `codium`; `blender`, `ghostty`, `lm-studio` and `unity-hub` put nothing there.
- Homebrew's `rustup` formula has no `rustup-init`.
- The Unity CLI's installer puts it in `~/.unity/bin/unity` on macOS, not `~/.local/bin`.
- `gdscript-formatter` ships `…-macos-aarch64.zip`. ArtCraft Launcher ships `artcraft-launcher-<version>-macos-universal.dmg`.
- `dotnet@10` is linked into Homebrew's `bin`; it wants `DOTNET_ROOT`.
- The firewall tool prints `Firewall is disabled. (State = 0)` when off. `pmset -g cap` lists `highpowermode`.
- `/Library/Preferences/org.mozilla.firefox.plist` doesn't exist; the per-user Firefox domain holds unrelated window state, so policies go in the system one.
- The Dock's apps read back with `defaults read com.apple.dock persistent-apps` as `"_CFURLString" = "file:///Applications/Firefox.app/";` lines.

## Review Focus

Each line is pinned by a test in the task named.

1. **A cask or formula fails to install** (renamed, network down): the run carries on and names it under "Left for you". Task 7.
2. **Not signed in to the App Store:** Xcode's install fails, the run carries on with one "Left for you" line, and no Xcode setup command runs. Task 7.
3. **A file of Jesse's already sits where a link goes, at a path with a space** (`~/Library/Application Support/VSCodium/User/settings.json`): it's moved to `.bak` intact, not overwritten. Task 2.
4. **`pam_reattach.so` isn't there when `sudo_local` is written:** the file names only `pam_tid.so`, so sudo can't be broken by a missing module. Task 9.
5. **A Dock app in the list isn't installed:** it's skipped and the rest are still set in order. Task 8.

---

## File Structure

**New**

| Path | Responsibility |
| --- | --- |
| `tests/run.sh`, `tests/helpers.sh`, `tests/test_*.sh` | The test runner, its sandbox and stub helpers, one test file per area |
| `shared/platform.sh` | What differs by OS for shared steps: `running`, `app_dir`, `APPS`, and the restart when an older `lib.sh` is in memory |
| `fedora/steps.sh`, `macos/steps.sh` | `os_install`, `os_update`, `os_uninstall`: that OS's step order |
| `macos/system.sh` | Homebrew formulae and casks, App Store apps and Xcode, removed Apple apps |
| `macos/apps.sh` | ArtCraft Launcher, Firefox's policies, the default browser, the environment of apps started from the Dock |
| `macos/desktop.sh` | `defaults.txt`, the Dock, power, the screenshots folder, `~/Library` |
| `macos/security.sh` | Touch ID for sudo, the firewall, FileVault's reminder, analytics |
| `macos/llm.sh` | LM Studio's settings |
| `macos/formulae.txt`, `casks.txt`, `appstore.txt`, `remove.txt`, `defaults.txt`, `dock.txt`, `power.txt` | The lists |
| `macos/home/<pkg>/…`, `fedora/home/<pkg>/…` | Config packages only that OS links |

**Moved (with `git mv`)**

| From | To |
| --- | --- |
| `home/gaming/` | `fedora/home/gaming/` |
| `home/gtk/` | `fedora/home/gtk/` |
| `home/ghostty/.config/xdg-terminals.list` | `fedora/home/terminal/.config/xdg-terminals.list` |
| `home/ghostty/.local/bin/x-terminal-emulator` | `fedora/home/terminal/.local/bin/x-terminal-emulator` |
| `home/zsh/.config/environment.d/10-dotfiles.conf` | `fedora/home/environment/.config/environment.d/10-dotfiles.conf` |
| `home/vscodium/.config/VSCodium/User/settings.json` | `shared/vscodium-settings.json` |
| `fedora/firefox-policies.json` | `shared/firefox-policies.json` |

**Changed:** `lib.sh`, `install.sh`, `update.sh`, `uninstall.sh`, every `shared/*.sh` that names a Linux path or command, `fedora/apps.sh` (the policies path), `home/zsh/**`, `home/git/.config/git/config`, `home/ghostty/.config/ghostty/config`, `home/godot/.local/bin/godot-nvim`, `home/nvim/.config/nvim/lua/godot.lua`, `home/unity/.local/bin/unity-project`, `home/claude/.claude/CLAUDE.md`, `home/claude/.local/bin/blender-lab-mcp`, `README.md`, `CHANGELOG.md`.

---

### Task 1: Test harness, portable helpers, platform helpers

**Files:**
- Create: `tests/run.sh`, `tests/helpers.sh`, `tests/test_lib.sh`, `shared/platform.sh`
- Modify: `lib.sh` (`os_id`, `package_files`, `package_dirs`, new `link_dest`, new `DOT_LIB`)

**Interfaces:**
- Produces, in `tests/helpers.sh` (every later test file starts with `source "$(dirname "$0")/helpers.sh"`):
  - `set -euo pipefail`, so any failing line fails the file.
  - `$T` (exported): a temp folder, removed on exit. `HOME=$T/home`, `APPS=$T/Applications`, `$T/bin` first on `PATH`, `XDG_*` unset, `GIT_CONFIG_NOSYSTEM=1`. `$REPO` is the repo's root.
  - `stub <name> [bash body]`: an executable `$T/bin/<name>` that appends `<name> <args>` to `$T/calls`, then runs the body (default: exit 0). `stub sudo` is made by default and runs nothing.
  - `stub_download <text>`: a `curl` stub that writes `<text>` to the path after `-o`.
  - `calls`: prints `$T/calls`. `called <fixed string>` / `not_called <fixed string>`: assert a line of it contains / no line contains the string.
  - `eq <label> <want> <got>`, `ok <label> <cmd…>`, `no <label> <cmd…>`: assertions; a failure prints the label and exits 1.
  - `load <os>`: `export DOT_OS=<os>`, sources `lib.sh`, runs `load_steps <os>`.
- Produces, in `lib.sh`:
  - `DOT_LIB=2`: marks this `lib.sh` as the one the step files expect.
  - `os_id`: as now, but prints `$DOT_OS` when it's set (tests only).
  - `package_files <root> <pkg>` and `package_dirs <root> <pkg>`: as now but with the root given, and without `find -printf`.
  - `link_dest <link>`: the absolute path a symlink names, `..` folded, whether or not it exists.
- Produces, in `shared/platform.sh`:
  - `APPS=${APPS:-/Applications}`.
  - `running <name>…`: true when a process with any of the exact names is running (`pgrep -x`).
  - `app_dir <xdg name> <mac name>`: `${XDG_CONFIG_HOME:-$HOME/.config}/<xdg name>` on Linux, `$HOME/Library/Application Support/<mac name>` on macOS.
  - At source time, when `${DOT_LIB:-1}` is below 2: `export DOT_RESTARTED=1` and `exec "$0"`; when `DOT_RESTARTED` is already set, an error and `exit 1` instead, so it can't loop. This is for the Fedora machine: its first `dot update` after this lands starts under the old `update.sh` and old `lib.sh` already in memory, pulls, then sources the new step files, which need the new `lib.sh`.

- [ ] **Step 1: Write `tests/helpers.sh` and `tests/run.sh`**

`run.sh [name…]` runs `tests/test_<name>.sh` (all when none given) each in its own `bash`, prints `ok <file>` or `FAIL <file>`, skips files named `test_macos_*.sh` when `uname -s` isn't `Darwin`, and exits non-zero if any failed.

- [ ] **Step 2: Write the failing tests in `tests/test_lib.sh`**

```bash
source "$(dirname "$0")/helpers.sh"
source "$REPO/lib.sh"; source "$REPO/shared/platform.sh"

eq "os override" macos "$(DOT_OS=macos os_id)"

mkdir -p "$T/root/pkg/.config/my app"; touch "$T/root/pkg/.config/my app/a file"
ln -s "a file" "$T/root/pkg/.config/my app/l"
eq "package_files" "$(printf '%s\n' '.config/my app/a file' '.config/my app/l')" "$(package_files "$T/root" pkg | sort)"
eq "package_dirs" "$(printf '%s\n' .config '.config/my app')" "$(package_dirs "$T/root" pkg | sort)"

mkdir -p "$T/a/b"; ln -s ../../gone/x/y "$T/a/b/rel"; ln -s /nowhere/z "$T/a/b/abs"
eq "link_dest relative" "$(cd "$T" && pwd -P)/gone/x/y" "$(link_dest "$T/a/b/rel")"
eq "link_dest absolute" /nowhere/z "$(link_dest "$T/a/b/abs")"

stub pgrep '[[ $2 == Godot ]]'
ok "running finds the mac name" running godot Godot
no "running misses" running blender Blender

eq "app_dir fedora" "$HOME/.config/godot" "$(DOT_OS=fedora app_dir godot Godot)"
eq "app_dir macos" "$HOME/Library/Application Support/Godot" "$(DOT_OS=macos app_dir godot Godot)"

# an update begun by an older lib.sh starts again
cat >"$T/old.sh" <<EOF
#!/usr/bin/env bash
if [[ -n \${DOT_RESTARTED:-} ]]; then echo restarted; exit 0; fi
unset DOT_LIB; source "$REPO/shared/platform.sh"; echo "not restarted"
EOF
chmod +x "$T/old.sh"
eq "stale lib restarts" restarted "$("$T/old.sh")"
```

- [ ] **Step 3: Run it to see it fail**

Run: `bash tests/run.sh lib`
Expected: `FAIL test_lib.sh` (no `shared/platform.sh`, `package_files` takes one argument).

- [ ] **Step 4: Implement**

In `lib.sh`: add `DOT_LIB=2` beside `TODOS=()`; give `os_id` the `DOT_OS` line; rewrite `package_files` as `(cd "$1/$2" && find . \( -type f -o -type l \) | sed 's|^\./||')` and `package_dirs` as `(cd "$1/$2" && find . -mindepth 1 -type d | sed 's|^\./||')`; add `link_dest`, which reads the link's text, joins a relative one to the link's folder (made physical with `cd … && pwd -P`), and folds `.` and `..` by walking the parts. Keep everything in `lib.sh` parseable by bash 3.2. Write `shared/platform.sh` as described. The callers of `package_files`/`package_dirs` are only in `lib.sh` and change in Task 2; until then pass `"$DOTFILES/home"`.

- [ ] **Step 5: Run the tests and the lint**

Run: `bash tests/run.sh lib` → `ok test_lib.sh`
Run: `/bin/bash -n lib.sh && ~/.local/share/nvim/mason/bin/shellcheck -x lib.sh shared/platform.sh tests/*.sh` → no output

- [ ] **Step 6: Commit**

`git checkout -b macos`, then commit the spec, this plan and the task's files: `test: a sandboxed test runner, and helpers that don't need gnu find`.

---

### Task 2: Config packages per OS

**Files:**
- Modify: `lib.sh` (`home_roots`, `packages`, `link_home`, `unlink_home`, new `prune_links`)
- Move: the seven rows of the "Moved" table, except `fedora/firefox-policies.json` (Task 9)
- Create: `fedora/home/vscodium/.config/VSCodium/User/settings.json` → symlink to `../../../../../../shared/vscodium-settings.json`; `macos/home/vscodium/Library/Application Support/VSCodium/User/settings.json` → symlink to `../../../../../../../shared/vscodium-settings.json`
- Test: `tests/test_links.sh`

**Interfaces:**
- Consumes: `package_files <root> <pkg>`, `package_dirs <root> <pkg>`, `link_dest`, `os_id`.
- Produces:
  - `home_roots`: prints `$DOTFILES/home`, then `$DOTFILES/$(os_id)/home` when that folder exists.
  - `packages <root>`: the package names in a root.
  - `prune_links`: for every file of every package in every root, removes `~/<file>` when it is a symlink that points nowhere and whose `link_dest` is under `$DOTFILES`; says `removing a stale link, <path>`.
  - `link_home`: `prune_links`, then the existing two passes (stop on a folder linked from elsewhere; move what's in the way to `.bak`) over every root, then one `stow --no-folding --restow -d <root> -t "$HOME" <pkgs…>` per root, then the `dot` link.
  - `unlink_home`: `stow -D` per root, then the `.bak` restore over every root.

- [ ] **Step 1: Write the failing tests in `tests/test_links.sh`**

```bash
source "$(dirname "$0")/helpers.sh"
real() { readlink -f "$1"; }

# fedora links what it always did, from the new places
( load fedora; link_home ) >/dev/null
eq "gtk" "$REPO/fedora/home/gtk/.config/gtk-4.0/gtk.css" "$(real "$HOME/.config/gtk-4.0/gtk.css")"
eq "vscodium" "$REPO/shared/vscodium-settings.json" "$(real "$HOME/.config/VSCodium/User/settings.json")"
ok "x-terminal-emulator" test -x "$HOME/.local/bin/x-terminal-emulator"
ok "environment.d" test -f "$HOME/.config/environment.d/10-dotfiles.conf"
ok "steam-apps" test -x "$HOME/.local/bin/steam-apps"
ok "dot" test -L "$HOME/.local/bin/dot"
no "nothing mac-only" test -e "$HOME/Library"

# a fedora home linked by the old layout heals itself, with no .bak left behind
rm -rf "$HOME"; mkdir -p "$HOME/.config/gtk-4.0" "$HOME/.config/VSCodium/User"
ln -s "$REPO/home/gtk/.config/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
ln -s "$REPO/home/vscodium/.config/VSCodium/User/settings.json" "$HOME/.config/VSCodium/User/settings.json"
( load fedora; link_home ) >/dev/null
eq "gtk relinked" "$REPO/fedora/home/gtk/.config/gtk-4.0/gtk.css" "$(real "$HOME/.config/gtk-4.0/gtk.css")"
eq "no backups" "" "$(find "$HOME" -name '*.bak*')"

# macos links nothing linux-only
rm -rf "$HOME"; mkdir -p "$HOME"
( load macos; link_home ) >/dev/null
for p in .config/gtk-4.0 .config/gtk-3.0 .config/systemd .config/environment.d .config/xdg-terminals.list \
  .local/bin/x-terminal-emulator .local/bin/steam-apps .config/VSCodium; do
  no "no $p on macos" test -e "$HOME/$p"
done
eq "vscodium on macos" "$REPO/shared/vscodium-settings.json" \
  "$(real "$HOME/Library/Application Support/VSCodium/User/settings.json")"
ok "nvim still linked" test -f "$HOME/.config/nvim/init.lua"

# review focus 3: your own file at a path with a space is kept
rm -rf "$HOME"; mkdir -p "$HOME/Library/Application Support/VSCodium/User"
echo mine >"$HOME/Library/Application Support/VSCodium/User/settings.json"
( load macos; link_home ) >/dev/null
eq "kept" mine "$(cat "$HOME/Library/Application Support/VSCodium/User/settings.json.bak")"
( load macos; unlink_home ) >/dev/null
eq "restored" mine "$(cat "$HOME/Library/Application Support/VSCodium/User/settings.json")"

# a dead link to somewhere else isn't ours to delete
rm -rf "$HOME"; mkdir -p "$HOME/.config/git"; ln -s /nowhere/config "$HOME/.config/git/config"
( load macos; link_home ) >/dev/null
ok "foreign dead link kept as .bak" test -L "$HOME/.config/git/config.bak"
```

- [ ] **Step 2: Run it to see it fail**

Run: `bash tests/run.sh links` → `FAIL test_links.sh`

- [ ] **Step 3: Move the files and add the two symlinks**

`git mv` each row. Check `git status` shows renames, and that `home/ghostty` and `home/zsh` no longer hold the three Linux-only files.

- [ ] **Step 4: Implement `home_roots`, `packages <root>`, `prune_links`, and the new `link_home` and `unlink_home`**

- [ ] **Step 5: Run the tests and the lint**

Run: `bash tests/run.sh` → `ok test_lib.sh`, `ok test_links.sh`
Run: `/bin/bash -n lib.sh && ~/.local/share/nvim/mason/bin/shellcheck -x lib.sh` → no output

- [ ] **Step 6: Commit** — `refactor: config packages for one os live under that os`

---

### Task 3: Each OS names its steps; the entry scripts work from bash 3.2

**Files:**
- Create: `fedora/steps.sh`, `tests/test_steps.sh`
- Modify: `install.sh`, `update.sh`, `uninstall.sh`, `lib.sh` (`need_bash`, `brew_bootstrap`, `pull_dotfiles`, macOS `PATH` and Homebrew variables)

**Interfaces:**
- Produces:
  - `os_install`, `os_update`, `os_uninstall`: defined by `<os>/steps.sh`, each calling that OS's steps in order. `os_uninstall` ends by printing that OS's "these stay" note.
  - `need_bash "$@"`: returns at once under bash 4 or newer. Under an older bash on macOS: `brew_bootstrap`, then `exec /opt/homebrew/bin/bash "$0" "$@"`. On anything else: `die`.
  - `brew_bootstrap`: when `/opt/homebrew/bin/brew` is missing, `sudo -v`, then Homebrew's installer with `NONINTERACTIVE=1` (`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`); then `brew install bash` when `/opt/homebrew/bin/bash` is missing. Written for bash 3.2.
  - `pull_dotfiles`: as now, and when the pull moved `HEAD`, `exec "$0" "$@"` so the new scripts run.
  - On macOS `lib.sh` puts `/opt/homebrew/bin:/opt/homebrew/sbin` on `PATH` after `~/.local/bin`, mise's shims and cargo, and exports `HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_NO_ASK=1`.
- The entry scripts become: `source lib.sh`; `need_bash "$@"`; `os=$(os_id)`; `[[ -d $DOTFILES/$os ]] || die "these dotfiles support fedora and macos"`; (`pull_dotfiles` in update); `load_steps "$os"`; `os_install` / `os_update` / `os_uninstall`; the closing `todo`, `say "done"` and `todo_print` stay in `install.sh` and `update.sh`.

- [ ] **Step 1: Write the failing tests in `tests/test_steps.sh`**

```bash
source "$(dirname "$0")/helpers.sh"

# order <os> <function>: the step functions it calls, in order
order() (
  load "$1"
  for f in $(declare -F | awk '{print $3}' | grep -E '_(install|update|uninstall)$|^(ask_questions|keep_sudo|set_hostname|link_home|unlink_home)$'); do
    [[ $f == os_* ]] || eval "$f() { echo $f; }"
  done
  "$2" | grep -E '^[a-z_]+$' | tr '\n' ' '
)
eq "fedora install" "ask_questions keep_sudo set_hostname system_install apps_install link_home shell_install git_install toolchains_install neovim_install vscodium_install godot_install unity_install claude_install gnome_install gaming_install llm_install " "$(order fedora os_install)"
eq "fedora update" "keep_sudo system_update apps_update link_home shell_update toolchains_update neovim_update vscodium_update unity_update claude_update godot_update gnome_update gaming_update llm_update " "$(order fedora os_update)"
eq "fedora uninstall" "unlink_home gaming_uninstall apps_uninstall neovim_uninstall godot_uninstall unity_uninstall " "$(order fedora os_uninstall)"
ok "fedora's note survives" grep -q "the packages, Flatpaks and repos install added" "$REPO/fedora/steps.sh"

for f in lib.sh install.sh update.sh uninstall.sh bin/dot; do ok "bash 3.2 parses $f" /bin/bash -n "$REPO/$f"; done

# on a mac with only bash 3.2, install.sh hands itself to homebrew's bash
if [[ $(/bin/bash -c 'echo ${BASH_VERSINFO[0]}') -lt 4 ]]; then
  printf '#!/bin/sh\necho "re-exec $*"\n' >"$T/newbash"; chmod +x "$T/newbash"
  out=$(DOT_OS=macos DOT_BREW_BASH="$T/newbash" /bin/bash -c "source '$REPO/lib.sh'; brew_bootstrap() { :; }; need_bash a b" script 2>&1)
  eq "re-exec" "re-exec script a b" "$out"
fi
```

`need_bash` execs `${DOT_BREW_BASH:-/opt/homebrew/bin/bash}`; the variable exists for this test.

- [ ] **Step 2: Run it to see it fail** — `bash tests/run.sh steps` → `FAIL test_steps.sh`

- [ ] **Step 3: Write `fedora/steps.sh`**

Move the step calls out of `install.sh`, `update.sh` and `uninstall.sh` exactly as they stand, and the "These stay" heredoc and `say "removing the links"` from `uninstall.sh` into `os_uninstall`.

- [ ] **Step 4: Rewrite the three entry scripts and add `need_bash`, `brew_bootstrap`, the `pull_dotfiles` restart and the macOS environment to `lib.sh`**

- [ ] **Step 5: Run the tests and the lint**

Run: `bash tests/run.sh` → three `ok` lines
Run: shellcheck on `lib.sh install.sh update.sh uninstall.sh fedora/steps.sh` → no output

- [ ] **Step 6: Commit** — `refactor: each os lists its own steps, and install starts from macos's bash 3.2`

---

### Task 4: The linked files, right on both

**Files:**
- Modify: `home/zsh/.zshenv`, `home/zsh/.config/zsh/.zshrc`, `home/zsh/.config/zsh/functions.zsh`, `home/git/.config/git/config`, `home/ghostty/.config/ghostty/config`, `home/claude/.claude/CLAUDE.md`
- Create: `fedora/home/git/.config/git/credential`, `macos/home/git/.config/git/credential`, `fedora/home/claude/.claude/machine.md`, `macos/home/claude/.claude/machine.md`, `macos/home/ghostty/.config/ghostty/os.conf`, `macos/home/blender/.local/bin/blender`
- Test: `tests/test_home.sh`

**What each must say**

- `.zshenv`: when `/opt/homebrew` exists, `export HOMEBREW_PREFIX=/opt/homebrew HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1`, put `/opt/homebrew/bin` and `/opt/homebrew/sbin` at the front of `path` **before** the existing line that puts `~/.local/bin`, mise's shims and cargo first, and `export DOTNET_ROOT=/opt/homebrew/opt/dotnet@10/libexec` when that folder exists. On Fedora the file behaves as it does now.
- `.zshrc`: the two plugins load from the first of `/usr/share` and `$HOMEBREW_PREFIX/share` that has them.
- `functions.zsh`: `oh`, `ffs` and `localhost` use `setsid -f xdg-open` where `xdg-open` exists, else `open`.
- `git/config`: the `[credential] helper = libsecret` lines become `[include] path = ~/.config/git/credential`, in the same place (before the two GitHub sections, whose empty `helper =` must still come after it). `fedora/…/credential` holds `[credential]` / `helper = libsecret`; `macos/…/credential` holds `helper = osxkeychain`. Each keeps a comment saying where HTTPS logins are kept.
- `ghostty/config`: one added line, `config-file = ?os.conf`. `macos/…/os.conf` holds `macos-option-as-alt = true` and `background-blur = true`, each with a comment (Alt for Claude Code's Alt+S, fzf and tmux; the blur Blur my Shell gives on Fedora).
- `CLAUDE.md`: the two Fedora-only bullets under "This machine" become the line `@~/.claude/machine.md`; the toolchains and dotfiles bullets stay. `fedora/…/machine.md` holds the two bullets moved out. `macos/…/machine.md` holds:

```markdown
- macOS on Apple Silicon.
- Packages come from Homebrew: formulae and casks from its main repos, listed in the dotfiles'
  `macos/formulae.txt` and `macos/casks.txt`. No third-party taps unless I ask.
```

- `macos/home/blender/.local/bin/blender`: a bash script that `exec`s `/Applications/Blender.app/Contents/MacOS/Blender "$@"`, as the cask puts no `blender` on the PATH and `shared/claude.sh` runs it by name.

- [ ] **Step 1: Write the failing tests in `tests/test_home.sh`**

```bash
source "$(dirname "$0")/helpers.sh"
for f in .zshenv .config/zsh/.zshrc .config/zsh/aliases.zsh .config/zsh/functions.zsh; do
  ok "zsh parses $f" zsh -n "$REPO/home/zsh/$f"
done
paths=$(HOME=$HOME zsh -f -c "source '$REPO/home/zsh/.zshenv'; print -l \$path")
eq "your scripts first" "$HOME/.local/bin" "$(sed -n 1p <<<"$paths")"
eq "then mise" "$HOME/.local/share/mise/shims" "$(sed -n 2p <<<"$paths")"
eq "then cargo" "$HOME/.cargo/bin" "$(sed -n 3p <<<"$paths")"
if [[ -d /opt/homebrew ]]; then eq "then homebrew" /opt/homebrew/bin "$(sed -n 4p <<<"$paths")"; fi

# GIT_CONFIG_NOSYSTEM (from helpers.sh) matters here: homebrew's git sets osxkeychain system-wide
helper() ( load "$1"; link_home >/dev/null; git config --get-all credential.helper; git config --get-urlmatch credential.helper https://github.com )
eq "macos logins" "$(printf '%s\n' osxkeychain '!gh auth git-credential')" "$(helper macos)"
rm -rf "$HOME"; mkdir -p "$HOME"
eq "fedora logins" "$(printf '%s\n' libsecret '!gh auth git-credential')" "$(helper fedora)"

rm -rf "$HOME"; mkdir -p "$HOME"; ( load macos; link_home ) >/dev/null
ok "claude reads the machine file" grep -qxF '@~/.claude/machine.md' "$HOME/.claude/CLAUDE.md"
ok "mac machine file" grep -q Homebrew "$HOME/.claude/machine.md"
no "no dnf on the mac" grep -q dnf "$HOME/.claude/CLAUDE.md" "$HOME/.claude/machine.md"
ok "blender wrapper" test -x "$HOME/.local/bin/blender"
ok "option is alt" grep -qx 'macos-option-as-alt = true' "$HOME/.config/ghostty/os.conf"
g=/Applications/Ghostty.app/Contents/MacOS/ghostty
if [[ -x $g ]]; then ok "ghostty accepts its config" "$g" +validate-config --config-file="$HOME/.config/ghostty/config"; fi
```

- [ ] **Step 2: Run it to see it fail** — `bash tests/run.sh home` → `FAIL test_home.sh`
- [ ] **Step 3: Make the changes above**
- [ ] **Step 4: Run the tests** — `bash tests/run.sh` → four `ok` lines; shellcheck the blender wrapper → no output
- [ ] **Step 5: Commit** — `feat(macos): the shell, git, ghostty and claude's notes read right on both`

---

### Task 5: Shared steps on macOS (all but Unity)

**Files:**
- Modify: `shared/questions.sh`, `shared/shell.sh`, `shared/toolchains.sh`, `shared/godot.sh`, `shared/lmstudio.sh`, `shared/claude.sh`, `home/godot/.local/bin/godot-nvim`, `home/nvim/.config/nvim/lua/godot.lua`, `home/claude/.local/bin/blender-lab-mcp`
- Test: `tests/test_shared.sh`

**Interfaces:**
- Consumes: `running`, `app_dir`, `os_id`, `APPS`.
- Produces / changes:
  - `current_hostname`: on macOS, `scutil --get ComputerName`.
  - `set_hostname`: on macOS, `ComputerName` is the name as typed; `LocalHostName` and `HostName` are `hostname_local <name>`.
  - `hostname_local <name>`: the name with spaces as hyphens and every character outside `A-Za-z0-9-` dropped.
  - `shell_install`: on macOS reads the login shell with `dscl . -read "/Users/$USER" UserShell`; when it doesn't end in `/zsh`, `as_root chsh -s /bin/zsh "$USER"`.
  - `toolchains_rust`: on macOS, where Homebrew has no `rustup-init`, `fetch https://sh.rustup.rs` to a temp file and run it with `sh`, with the same arguments `rustup-init` gets now. Fedora still runs `rustup-init`. So rustup isn't in `formulae.txt`.
  - `godot_formatter_asset`: `'^gdscript-formatter-.*-linux-x86_64\.zip$'` on Fedora, `'^gdscript-formatter-.*-macos-aarch64\.zip$'` on macOS.
  - `godot_settings` / `godot_uninstall`: the folder is `app_dir godot Godot`; "is it open" is `running godot Godot`.
  - `lmstudio_settings`: "is it open" is `running lm-studio "LM Studio"`.
  - `claude_blender`: the config folder is `$(app_dir blender Blender)/<series>`; "is it open" is `running blender Blender`. `claude_servers` looks for Blender Lab's add-on under the same folder and for Playwright's Chromium under `~/Library/Caches/ms-playwright` on macOS.
  - `godot-nvim` and `godot.lua`: the socket folder is `${XDG_RUNTIME_DIR:-$HOME/.local/state}/godot-nvim` in both; the project's real path comes from `cd … && pwd -P`, not `realpath -e`. A new window is `ghostty +new-window -e nvim …` on Linux and `open -na Ghostty.app --args --quit-after-last-window-closed=true -e nvim …` on macOS (chosen by `uname -s`), with the same Neovim arguments.
  - `blender-lab-mcp`: finds the manifest under `~/Library/Application Support/Blender` when `uname -s` is `Darwin`.

- [ ] **Step 1: Write the failing tests in `tests/test_shared.sh`**

```bash
source "$(dirname "$0")/helpers.sh"

( load macos
  stub scutil '[[ $1 == --get ]] && echo Zero'
  eq "reads the name" Zero "$(current_hostname)"
  eq "local name" Zeros-Mac "$(hostname_local "Zero's Mac")"
  NEW_HOSTNAME="Zero's Mac" set_hostname >/dev/null
  called "scutil --set ComputerName Zero's Mac"; called "scutil --set LocalHostName Zeros-Mac"; called "scutil --set HostName Zeros-Mac"
  : >"$T/calls"; NEW_HOSTNAME=Zero set_hostname; not_called "--set" )

( load macos; fzf_tab() { :; }; atuin_import() { :; }; btop_colours() { :; }
  stub dscl 'echo "UserShell: /bin/zsh"'; shell_install; not_called chsh
  stub dscl 'echo "UserShell: /bin/bash"'; shell_install >/dev/null; called "chsh -s /bin/zsh" )

eq "mac formatter" '^gdscript-formatter-.*-macos-aarch64\.zip$' "$(load macos; godot_formatter_asset)"
eq "fedora formatter" '^gdscript-formatter-.*-linux-x86_64\.zip$' "$(load fedora; godot_formatter_asset)"

( load macos; stub godot 'echo 4.7.2.stable.official'; stub pgrep 'exit 1'
  godot_settings >/dev/null
  f="$HOME/Library/Application Support/Godot/editor_settings-4.7.tres"
  ok "godot's settings on the mac" grep -qxF "text_editor/external/exec_path = \"$HOME/.local/bin/godot-nvim\"" "$f" )

( load macos; stub pgrep 'exit 1'; stub uvx; stub blender '[[ $1 == --version ]] && echo "Blender 5.3.0"'
  claude_blender >/dev/null || true
  called "--addons-dir $HOME/Library/Application Support/Blender/5.3/scripts/addons" )

( load macos; stub_download 'exit 0'; stub sh; mkdir -p "$HOME/.cargo"
  toolchains_rust >/dev/null
  called "https://sh.rustup.rs"; called "-y --no-modify-path --default-toolchain stable -c rust-analyzer -c rust-src" )

mkdir -p "$T/proj"; touch "$T/proj/project.godot"; stub nvim 'exit 1'; stub git 'exit 1'
stub uname 'echo Darwin'; stub open
"$REPO/home/godot/.local/bin/godot-nvim" "$T/proj" "$T/proj/a.gd" 3 1
called "open -na Ghostty.app --args --quit-after-last-window-closed=true -e nvim"
stub uname 'echo Linux'; stub ghostty
"$REPO/home/godot/.local/bin/godot-nvim" "$T/proj" "$T/proj/a.gd" 3 1
called "ghostty +new-window -e nvim"
ok "lua agrees on the socket" grep -q 'XDG_RUNTIME_DIR or (vim.env.HOME .. "/.local/state")' "$REPO/home/nvim/.config/nvim/lua/godot.lua"
```

- [ ] **Step 2: Run it to see it fail** — `bash tests/run.sh shared` → `FAIL test_shared.sh`
- [ ] **Step 3: Make the changes in the Interfaces block.** Every Fedora path through these functions must run the same commands it does now; the OS branch is the only addition.
- [ ] **Step 4: Run the tests and the lint** — `bash tests/run.sh` → five `ok` lines; shellcheck each changed shell file → no output
- [ ] **Step 5: Commit** — `feat(macos): the shared steps know macos's folders, process names and commands`

---

### Task 6: Unity on macOS

**Files:**
- Modify: `shared/unity.sh`, `home/unity/.local/bin/unity-project`
- Test: `tests/test_unity.sh`

**Interfaces:**
- Consumes: `running`, `os_id`, `APPS`, `todo`.
- Produces:
  - `unity_cli`: after the installer, on macOS, `ln -sfn "$HOME/.unity/bin/unity" "$HOME/.local/bin/unity"` when the first exists, so every other use of `~/.local/bin/unity` holds on both.
  - `unity_running`: also matches `/Unity.app/Contents/MacOS/Unity`.
  - `unity_editor`: `unity_vscodium` on macOS, `unity_neovim` elsewhere. `unity_install`, `unity_update` and `unity-project` call it where they call `unity_neovim` today.
  - `unity_vscodium`: Unity's script editor is the `kScriptsDefaultApp` string in the `com.unity3d.UnityEditor5.x` preferences domain. When `$APPS/VSCodium.app` exists and the key is unset or empty: with Unity open, `todo "close Unity and run dot install again, so Unity opens scripts in VSCodium"`; otherwise `defaults write com.unity3d.UnityEditor5.x kScriptsDefaultApp -string "$APPS/VSCodium.app"`. A value already there, Jesse's or ours, is left.
  - `unity_uninstall`: on macOS, when the key is `$APPS/VSCodium.app` and Unity is closed, `defaults delete com.unity3d.UnityEditor5.x kScriptsDefaultApp`.
  - `unity-project` on macOS still adds both packages and still runs `unity_vulkan` (the spec's call), then `unity_editor`.

- [ ] **Step 1: Write the failing tests in `tests/test_unity.sh`**

```bash
source "$(dirname "$0")/helpers.sh"
D=com.unity3d.UnityEditor5.x
mkdir -p "$APPS/VSCodium.app"

( load macos; stub pgrep 'exit 1'; stub defaults '[[ $1 == read ]] && exit 1; exit 0'
  unity_editor >/dev/null; called "defaults write $D kScriptsDefaultApp -string $APPS/VSCodium.app" )
( load macos; stub pgrep 'exit 1'; stub defaults '[[ $1 == read ]] && echo /Applications/Rider.app'
  unity_editor; not_called "defaults write" )
( load macos; stub pgrep 'exit 0'; stub defaults '[[ $1 == read ]] && exit 1; exit 0'
  unity_editor; not_called "defaults write"; [[ ${TODOS[*]} == *"close Unity"* ]] || exit 1 )
( load macos; stub pgrep 'exit 1'; stub defaults "[[ \$1 == read ]] && echo $APPS/VSCodium.app"
  mkdir -p "$HOME/Library/Preferences"; unity_uninstall >/dev/null; called "defaults delete $D kScriptsDefaultApp" )
( load fedora; unity_neovim() { echo neovim; }; unity_vscodium() { echo vscodium; }
  eq "fedora stays on neovim" neovim "$(unity_editor)" )

( load macos; stub_download "mkdir -p \"\$HOME/.unity/bin\"; printf '#!/bin/sh\n' >\"\$HOME/.unity/bin/unity\"; chmod +x \"\$HOME/.unity/bin/unity\""
  unity_cli >/dev/null; eq "cli linked" "$HOME/.unity/bin/unity" "$(readlink "$HOME/.local/bin/unity")" )
```

- [ ] **Step 2: Run it to see it fail** — `bash tests/run.sh unity` → `FAIL test_unity.sh`
- [ ] **Step 3: Implement.** The XML-prefs functions (`unity_pref`, `unity_pref_set`, `unity_pref_del`) and `unity_neovim` stay as they are, Fedora's alone.
- [ ] **Step 4: Run the tests and the lint** — six `ok` lines; shellcheck `shared/unity.sh home/unity/.local/bin/unity-project` → no output
- [ ] **Step 5: Commit** — `feat(macos): unity opens scripts in vscodium on macos`

Whether Unity treats VSCodium as Visual Studio Code (project files, line numbers) can only be seen with an Editor; Task 12 checks it.

---

### Task 7: Homebrew, the App Store and removed apps

**Files:**
- Create: `macos/system.sh`, `macos/formulae.txt`, `macos/casks.txt`, `macos/appstore.txt`, `macos/remove.txt`, `tests/test_macos_system.sh`

**The lists** (each with a one-line `#` header in the repo's voice, and `#` group comments as in `fedora/packages.txt`)

`formulae.txt`:

```
bash stow jq gh git git-lfs git-delta lazygit
zsh-autosuggestions zsh-syntax-highlighting starship atuin zoxide fzf eza bat fd ripgrep
tmux btop
mise uv dotnet@10
neovim tree-sitter-cli
numpy scipy pillow opencv
rizin binwalk
mas defaultbrowser pam-reattach
```

(one a line in the file; grouped here to save space)

`casks.txt`: `ghostty`, `vscodium`, `blender`, `godot`, `unity-hub`, `obs`, `firefox`, `vesktop`, `spotify`, `lm-studio`, `font-jetbrains-mono-nerd-font`.

`appstore.txt`: `497799835 Xcode` (id, then the name used in messages).

`remove.txt`: `GarageBand`, `iMovie`, `Keynote`, `Numbers`, `Pages` (the app's name in `/Applications`, without `.app`).

**Interfaces:**
- Consumes: `list`, `say`, `warn`, `todo`, `as_root`, `have`, `APPS`.
- Produces:
  - `system_first`: installs `gh`, `jq` and `stow` when missing, so the questions and the linking can run.
  - `system_install`: `system_formulae`, `system_casks`, `system_appstore`, `xcode_setup`, `system_removals`.
  - `system_formulae` / `system_casks`: what `brew list --formula -1` / `brew list --cask -1` doesn't name is installed one at a time (`brew install <f>` / `brew install --cask <c>`); a failure is `todo "<name> didn't install; run dot install again"` and the loop goes on.
  - `system_appstore`: each id `mas list` doesn't show gets `mas install <id>`; a failure is `todo "sign in to the App Store, then run dot install again for <name>"`.
  - `xcode_setup`: only when `$APPS/Xcode.app` exists: `xcode-select -s` to it when `xcode-select -p` names another place, `xcodebuild -license accept` when `xcodebuild -license check` fails, `xcodebuild -runFirstLaunch` when `xcodebuild -checkFirstLaunchStatus` fails; each through `as_root`.
  - `system_removals`: each `$APPS/<name>.app` that exists is removed with `as_root rm -rf`; one that's still there after is `todo "remove <name> yourself: macOS wouldn't let the terminal"`. When `GarageBand` is in the list and neither `$APPS/Logic Pro.app` nor `$APPS/MainStage.app` exists, the folders in `GARAGEBAND_FILES` that exist go too.
  - `GARAGEBAND_FILES`: `/Library/Application Support/GarageBand`, `/Library/Application Support/Logic`, `/Library/Audio/Apple Loops`; overridable from the environment for tests.
  - `system_update`: `brew update`, `brew upgrade`, then `mas upgrade`; each failure a `warn`.

- [ ] **Step 1: Write the failing tests in `tests/test_macos_system.sh`**

```bash
source "$(dirname "$0")/helpers.sh"
all() { list "$REPO/macos/$1"; }

( load macos; all formulae.txt | grep -vx binwalk >"$T/installed"
  stub brew '[[ "$*" == "list --formula -1" ]] && cat "$T/installed"; exit 0'
  system_formulae >/dev/null; called "brew install binwalk"
  eq "only the missing one" 1 "$(calls | grep -c '^brew install')" )

# review focus 1: one cask failing doesn't stop the rest
( load macos; stub brew '[[ "$*" == "install --cask vesktop" ]] && exit 1; exit 0'
  system_casks >/dev/null 2>&1; called "brew install --cask spotify"
  [[ ${TODOS[*]} == *vesktop* ]] || exit 1 )

# review focus 2: no app store sign-in
( load macos; stub mas '[[ $1 == install ]] && exit 1; exit 0'; stub xcodebuild; stub xcode-select
  system_appstore >/dev/null 2>&1; xcode_setup
  [[ ${TODOS[*]} == *"sign in to the App Store"* ]] || exit 1
  not_called xcodebuild; not_called "xcode-select -s" )

( load macos; mkdir -p "$APPS/GarageBand.app" "$APPS/Pages.app" "$T/loops"
  GARAGEBAND_FILES=("$T/loops" "$T/absent"); system_removals >/dev/null 2>&1
  called "sudo rm -rf $APPS/GarageBand.app"; called "sudo rm -rf $APPS/Pages.app"; called "sudo rm -rf $T/loops"
  not_called "$APPS/iMovie.app"; not_called "$T/absent" )
( load macos; mkdir -p "$APPS/GarageBand.app" "$APPS/Logic Pro.app" "$T/loops"
  GARAGEBAND_FILES=("$T/loops"); system_removals >/dev/null 2>&1; not_called "rm -rf $T/loops" )

( load macos; stub brew; stub mas; system_update >/dev/null
  called "brew update"; called "brew upgrade"; called "mas upgrade" )
```

- [ ] **Step 2: Run it to see it fail** — `bash tests/run.sh macos_system` → `FAIL`
- [ ] **Step 3: Write the lists and `macos/system.sh`**
- [ ] **Step 4: Run the tests and the lint** — seven `ok` lines; shellcheck `macos/system.sh` → no output
- [ ] **Step 5: Commit** — `feat(macos): homebrew's formulae and casks, xcode, and apple's apps removed`

---

### Task 8: System settings, the Dock and power

**Files:**
- Create: `macos/desktop.sh`, `macos/defaults.txt`, `macos/dock.txt`, `macos/power.txt`, `tests/test_macos_desktop.sh`

**`macos/defaults.txt`**: `[-currentHost] <domain> <key> <type> <value>`, with `type` one of `bool`, `int`, `float`, `string`, `delete` (no value; the key is removed), and a leading `~` in a value meaning the home folder. Its content, under the spec's three headings as `#` comments:

```
# copied from this mac
NSGlobalDomain AppleInterfaceStyle string Dark
com.apple.WindowManager StandardHideDesktopIcons bool true
com.apple.WindowManager HideDesktop bool true
com.apple.WindowManager StandardHideWidgets bool true
com.apple.WindowManager StageManagerHideWidgets bool true
com.apple.WindowManager EnableTiledWindowMargins bool false
com.apple.dock autohide bool true
com.apple.dock tilesize int 48
com.apple.dock show-recents bool false
com.apple.finder FXPreferredViewStyle string Nlsv
com.apple.finder ShowPathbar bool true
NSGlobalDomain AppleShowAllExtensions bool true
com.apple.finder NewWindowTarget string PfHm
com.apple.finder FXRemoveOldTrashItems bool true
NSGlobalDomain KeyRepeat int 2
NSGlobalDomain InitialKeyRepeat int 15
com.apple.AppleMultitouchTrackpad Clicking bool true
com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking bool true
-currentHost NSGlobalDomain com.apple.mouse.tapBehavior int 1
NSGlobalDomain com.apple.swipescrolldirection bool true
NSGlobalDomain com.apple.mouse.linear bool true
NSGlobalDomain com.apple.mouse.scaling float 0.6875
com.apple.HIToolbox AppleFnUsageType int 0

# matching fedora
com.apple.dock wvous-tl-corner int 1
com.apple.dock wvous-tr-corner int 1
com.apple.dock wvous-bl-corner int 1
com.apple.dock wvous-br-corner int 1

# for development
com.apple.finder AppleShowAllFiles bool true
com.apple.finder ShowStatusBar bool true
com.apple.finder _FXShowPosixPathInTitle bool true
com.apple.finder _FXSortFoldersFirst bool true
com.apple.finder FXDefaultSearchScope string SCcf
com.apple.finder FXEnableExtensionChangeWarning bool false
com.apple.desktopservices DSDontWriteNetworkStores bool true
com.apple.desktopservices DSDontWriteUSBStores bool true
NSGlobalDomain ApplePressAndHoldEnabled bool false
NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled bool false
NSGlobalDomain NSAutomaticDashSubstitutionEnabled bool false
NSGlobalDomain NSAutomaticSpellingCorrectionEnabled bool false
NSGlobalDomain NSAutomaticCapitalizationEnabled bool false
NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled bool false
NSGlobalDomain NSAutomaticInlinePredictionEnabled bool false
NSGlobalDomain AppleKeyboardUIMode int 2
com.apple.dock autohide-delay float 0
com.apple.dock mru-spaces bool false
com.apple.screencapture location string ~/Pictures/Screenshots
com.apple.screencapture type string png
NSGlobalDomain NSNavPanelExpandedStateForSaveMode bool true
NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 bool true
NSGlobalDomain PMPrintingExpandedStateForPrint bool true
NSGlobalDomain PMPrintingExpandedStateForPrint2 bool true
NSGlobalDomain NSDocumentSaveNewDocumentsToCloud bool false
```

The accent's lines are added in Task 11, once Jesse has looked at Graphite on the screen.

**`macos/dock.txt`**: `Firefox`, `Vesktop`, `Godot`, `VSCodium`, `Ghostty`, `Blender`, `Spotify` (an app's name in `/Applications`; a line starting with `/` is a full path to an app).

**`macos/power.txt`**: `<charger|battery> <pmset setting> <value>`: `charger powermode 2`, `charger displaysleep 0`.

**Interfaces:**
- Produces:
  - `desktop_install`: `desktop_folders`, `defaults_apply`, `dock_apply`, `power_apply`.
  - `desktop_folders`: makes `~/Pictures/Screenshots`; `chflags nohidden ~/Library` when it's hidden.
  - `defaults_same <type> <have> <want>`: true when they mean the same: `bool` treats `1`/`true` and `0`/`false` alike; `int` and `float` compare as numbers (`2` equals `2.0`); `string` is exact.
  - `defaults_apply`: for each line, reads the key (`defaults [-currentHost] read <domain> <key>`; a failed read means unset), and when it differs writes it with `defaults [-currentHost] write <domain> <key> -<type> <value>`, or `defaults delete` for `delete` when the key is set. After: `killall Finder` if a `com.apple.finder` or `com.apple.desktopservices` key changed, `killall Dock` for `com.apple.dock`, `killall SystemUIServer` for `com.apple.screencapture`, and one `todo "log out and back in, for the keyboard, mouse and appearance settings"` if any other domain changed.
  - `dock_url <name or path>`: `file://<path>/` with spaces as `%20`.
  - `dock_apply`: the wanted urls are those of the listed apps that exist; when they differ from the Dock's (`defaults read com.apple.dock persistent-apps`, the `_CFURLString` lines), `defaults write com.apple.dock persistent-apps -array <one dict per app>` then `killall Dock`. Each dict: `<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>URL</string><key>_CFURLStringType</key><integer>15</integer></dict></dict><key>tile-type</key><string>file-tile</string></dict>`.
  - `power_apply`: for each line whose value differs from `pmset -g custom` (the `AC Power:` section for `charger`, `Battery Power:` for `battery`), `as_root pmset -c|-b <setting> <value>`; a `powermode 2` line is skipped when `pmset -g cap` has no `highpowermode`.

- [ ] **Step 1: Add `stub_defaults` to `tests/helpers.sh`, then write the failing tests in `tests/test_macos_desktop.sh`**

`stub_defaults`: a `defaults` stub that logs every call like any stub and answers reads from files: `read <domain> <key>` (with or without a leading `-currentHost`) prints the value from the `$T/have` line `<domain> <key> <value>` and exits 1 when there's none; `read com.apple.dock persistent-apps` prints `$T/dock`. Every other call exits 0.

```bash
source "$(dirname "$0")/helpers.sh"
load macos

ok "bool" defaults_same bool 1 true;      no "bool differs" defaults_same bool 0 true
ok "int as float" defaults_same int 2.0 2; ok "float" defaults_same float 0.6875 0.6875
no "string differs" defaults_same string icnv Nlsv

stub_defaults; stub killall
want() { list "$REPO/macos/defaults.txt" | sed 's/^-currentHost //' | awk -v h="$HOME" '$3!="delete" { v=$4; for(i=5;i<=NF;i++) v=v" "$i; sub(/^~/,h,v); if($3=="bool") v=(v=="true"?1:0); print $1, $2, v }'; }

want >"$T/have"; ( defaults_apply ); not_called "defaults write"; not_called killall
( defaults_apply; [[ ${#TODOS[@]} == 0 ]] )

want | grep -v ' ShowPathbar ' >"$T/have"; : >"$T/calls"
( defaults_apply >/dev/null ); called "defaults write com.apple.finder ShowPathbar -bool true"
eq "one write" 1 "$(calls | grep -c 'defaults write')"; eq "finder restarted once" 1 "$(calls | grep -c 'killall Finder')"

: >"$T/have"; : >"$T/calls"; ( defaults_apply >/dev/null; [[ ${TODOS[*]} == *"log out and back in"* ]] )
called "defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1"
called "defaults write com.apple.screencapture location -string $HOME/Pictures/Screenshots"

# review focus 5: an app that isn't installed is skipped, the rest keep their order
mkdir -p "$APPS/Firefox.app" "$APPS/Ghostty.app"; : >"$T/calls"; : >"$T/dock"
( dock_apply >/dev/null ); line=$(calls | grep 'persistent-apps -array')
[[ $line == *Firefox.app*Ghostty.app* && $line != *Vesktop* ]] || exit 1; called "killall Dock"
printf '"_CFURLString" = "file://%s/";\n' "$APPS/Firefox.app" "$APPS/Ghostty.app" >"$T/dock"; : >"$T/calls"
( dock_apply ); not_called "defaults write"
eq "spaces" "file:///Applications/Unity%20Hub.app/" "$(dock_url "/Applications/Unity Hub.app")"

stub pmset '[[ $2 == cap ]] && { echo " highpowermode"; exit 0; }; printf "Battery Power:\n powermode 0\n displaysleep 2\nAC Power:\n powermode 0\n displaysleep 0\n"'
: >"$T/calls"; ( power_apply >/dev/null ); called "sudo pmset -c powermode 2"; not_called "displaysleep"
```

- [ ] **Step 2: Run it to see it fail** — `bash tests/run.sh macos_desktop` → `FAIL`
- [ ] **Step 3: Write the three lists and `macos/desktop.sh`**
- [ ] **Step 4: Run the tests and the lint** — eight `ok` lines; shellcheck `macos/desktop.sh` → no output
- [ ] **Step 5: Commit** — `feat(macos): finder, dock, keyboard and the rest of macos's settings, from a list`

---

### Task 9: Security, Firefox, the default browser, apps from the Dock

**Files:**
- Create: `macos/security.sh`, `macos/apps.sh`, `macos/llm.sh`, `tests/test_macos_apps.sh`
- Move: `fedora/firefox-policies.json` → `shared/firefox-policies.json`
- Modify: `fedora/apps.sh` (the one path)

**Interfaces:**
- Produces, in `macos/security.sh`:
  - `security_install`: `touch_id`, `firewall_on`, `filevault_check`, `analytics_off`.
  - `SUDO_LOCAL=${SUDO_LOCAL:-/etc/pam.d/sudo_local}`, `PAM_REATTACH=${PAM_REATTACH:-/opt/homebrew/lib/pam/pam_reattach.so}`.
  - `sudo_local_want`: prints the file: a `#` comment line, then `auth       optional       $PAM_REATTACH ignore_ssh` only when that file exists, then `auth       sufficient     pam_tid.so`.
  - `touch_id`: when `$SUDO_LOCAL` differs from `sudo_local_want`, writes it through `as_root tee`.
  - `firewall_on`: `FIREWALL=${FIREWALL:-/usr/libexec/ApplicationFirewall/socketfilterfw}`; when `--getglobalstate` doesn't say `enabled`, `as_root "$FIREWALL" --setglobalstate on` and `--setallowsigned on`.
  - `filevault_check`: `todo "turn on FileVault (System Settings > Privacy & Security)"` when `fdesetup status` doesn't say `FileVault is On.`
  - `analytics_off`: `AutoSubmit` and `ThirdPartyDataSubmit` set false in `/Library/Application Support/CrashReporter/DiagnosticMessagesHistory.plist` through `as_root defaults write`, each only when it reads as on; a failed write is a `warn`, nothing more.
- Produces, in `macos/apps.sh`:
  - `apps_install`: `apps_releases`, `firefox_policies`, `default_browser`. `apps_update`: `apps_releases`. `apps_uninstall`: removes the Firefox policies and the environment agent.
  - `apps_releases`: `dmg_release storytold/craft-launcher '^artcraft-launcher-.*-macos-universal\.dmg$' "ArtCraft Launcher"`, a failure being `todo "ArtCraft Launcher didn't install; dot update tries again"`.
  - `dmg_release <owner/repo> <asset regex> <app name>`: like Fedora's `rpm_release`. Skips when `$APPS/<app name>.app`'s `CFBundleShortVersionString` equals the latest tag without its `v`; otherwise fetches the dmg, `hdiutil attach -nobrowse -readonly` it, copies the `.app` inside to `$APPS` with `cp -R` (replacing the old one), detaches. The app's name inside the dmg is read from the dmg, not assumed.
  - `firefox_policies_want`: `jq -S '.policies + {EnterprisePoliciesEnabled: true}' shared/firefox-policies.json`.
  - `firefox_policies`: `FIREFOX_POLICIES=${FIREFOX_POLICIES:-/Library/Preferences/org.mozilla.firefox}`. Compares `firefox_policies_want` with the domain as json (`defaults export … - | plutil -convert json -o - -`, sorted with `jq -S`); when they differ, converts the wanted json to a plist with `plutil -convert xml1` and `as_root defaults import "$FIREFOX_POLICIES" <plist>`, then `todo "restart Firefox for its new policies; about:policies lists them"`.
  - `default_browser`: when the `https` handler in `defaults read com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers` isn't `org.mozilla.firefox` and `$APPS/Firefox.app` exists: `defaultbrowser firefox`, and `todo "confirm Firefox as the default browser in the dialog macOS shows"`.
  - `gui_env`: writes `~/Library/LaunchAgents/dev.dotfiles.environment.plist` (label `dev.dotfiles.environment`, `RunAtLoad`, running `/bin/zsh -c` with a line that does `launchctl setenv PATH "$PATH"` and the same for the four `UNITY_NO_*` variables, all of which `~/.zshenv` has set by then). When the file changed: `launchctl bootout gui/$UID/dev.dotfiles.environment` (ignoring failure), `launchctl bootstrap gui/$UID <file>`. It is written, not linked, so launchd reads a real file.
- Produces, in `macos/llm.sh`: `llm_install` and `llm_update`: `todo "open LM Studio once, then run dot install again to finish setting it up"` when `~/.lmstudio/bin/lms` isn't there, else `lmstudio_settings`.

- [ ] **Step 1: Write the failing tests in `tests/test_macos_apps.sh`**

```bash
source "$(dirname "$0")/helpers.sh"
load macos

# review focus 4: a missing pam_reattach leaves a file that can't break sudo
PAM_REATTACH="$T/absent.so"; eq "tid alone" 1 "$(sudo_local_want | grep -c '^auth')"
no "no reattach line" grep -q reattach <<<"$(sudo_local_want)"
touch "$T/reattach.so"; PAM_REATTACH="$T/reattach.so"
eq "reattach first" "$T/reattach.so" "$(sudo_local_want | awk '/^auth/ { print $3; exit }')"
eq "tid last" pam_tid.so "$(sudo_local_want | awk '/^auth/ { m=$3 } END { print m }')"
SUDO_LOCAL="$T/sudo_local"; sudo_local_want >"$SUDO_LOCAL"; ( touch_id ); not_called "sudo tee"
echo old >"$SUDO_LOCAL"; ( touch_id >/dev/null ); called "sudo tee $SUDO_LOCAL"

stub fw 'echo "Firewall is disabled. (State = 0)"'; FIREWALL="$T/bin/fw"; : >"$T/calls"
( firewall_on >/dev/null ); called "sudo $T/bin/fw --setglobalstate on"; called "--setallowsigned on"
stub fw 'echo "Firewall is enabled. (State = 1)"'; : >"$T/calls"; ( firewall_on ); not_called "sudo"

stub fdesetup 'echo "FileVault is Off."'; ( filevault_check; [[ ${TODOS[*]} == *FileVault* ]] )
stub fdesetup 'echo "FileVault is On."'; ( filevault_check; [[ ${#TODOS[@]} == 0 ]] )

ok "the policies firefox gets" jq -e '.EnterprisePoliciesEnabled == true and .HttpsOnlyMode == "enabled" and .DisableTelemetry == true and .ExtensionSettings["uBlock0@raymondhill.net"].installation_mode == "normal_installed" and (has("policies") | not)' <<<"$(firefox_policies_want)"
ok "fedora reads the moved file" grep -q 'shared/firefox-policies.json' "$REPO/fedora/apps.sh"

# handlers <bundle id>: the https handler as `defaults read … LSHandlers` prints it on this mac
handlers() { printf '(\n    {\n        LSHandlerRoleAll = "%s";\n        LSHandlerURLScheme = https;\n    }\n)\n' "$1" >"$T/handlers"; }
mkdir -p "$APPS/Firefox.app"; stub defaultbrowser; stub defaults 'cat "$T/handlers" 2>/dev/null || exit 1'
handlers com.apple.safari
( default_browser >/dev/null; [[ ${TODOS[*]} == *"default browser"* ]] ); called "defaultbrowser firefox"
handlers org.mozilla.firefox; : >"$T/calls"; ( default_browser ); not_called "defaultbrowser firefox"
# a fresh mac has no handlers at all, and safari is the default
rm "$T/handlers"; : >"$T/calls"; ( default_browser >/dev/null ); called "defaultbrowser firefox"

stub launchctl; ( gui_env >/dev/null ); f="$HOME/Library/LaunchAgents/dev.dotfiles.environment.plist"
ok "a valid plist" plutil -lint "$f"; ok "sets the path" grep -q 'launchctl setenv PATH' "$f"; called "launchctl bootstrap"
: >"$T/calls"; ( gui_env ); not_called "launchctl bootstrap"

gh_tag() { echo v0.19.2; }; mkdir -p "$APPS/ArtCraft Launcher.app/Contents"
plutil -create xml1 "$APPS/ArtCraft Launcher.app/Contents/Info.plist"
plutil -insert CFBundleShortVersionString -string 0.19.2 "$APPS/ArtCraft Launcher.app/Contents/Info.plist"
stub curl; stub hdiutil; : >"$T/calls"
( dmg_release storytold/craft-launcher 'x' "ArtCraft Launcher" ); not_called curl; not_called hdiutil
```

- [ ] **Step 2: Run it to see it fail** — `bash tests/run.sh macos_apps` → `FAIL`
- [ ] **Step 3: Move the policies file, fix `fedora/apps.sh`, and write the three macOS files**
- [ ] **Step 4: Run the tests and the lint** — nine `ok` lines; shellcheck `macos/*.sh fedora/apps.sh` → no output
- [ ] **Step 5: Commit** — `feat(macos): touch id for sudo, the firewall, firefox's policies and apps' environment`

---

### Task 10: The Mac's step order, the README and the changelog

**Files:**
- Create: `macos/steps.sh`
- Modify: `tests/test_steps.sh`, `README.md`, `CHANGELOG.md`

**Interfaces:**
- Consumes: every step function from Tasks 5–9.
- Produces `macos/steps.sh`:
  - `os_install`: `system_first ask_questions keep_sudo set_hostname system_install apps_install link_home gui_env shell_install git_install toolchains_install neovim_install vscodium_install godot_install unity_install claude_install desktop_install security_install llm_install`
  - `os_update`: `keep_sudo system_update apps_update link_home shell_update toolchains_update neovim_update vscodium_update unity_update claude_update godot_update llm_update`
  - `os_uninstall`: `unlink_home apps_uninstall neovim_uninstall godot_uninstall unity_uninstall`, then a note of what stays: Homebrew's packages and casks, Xcode, macOS's settings and the Dock, Touch ID for sudo and the firewall, the apps' data (the same list Fedora's note has), the Unity CLI in `~/.unity`, the git identity and SSH key.

- [ ] **Step 1: Add the failing tests to `tests/test_steps.sh`**

```bash
eq "macos install" "system_first ask_questions keep_sudo set_hostname system_install apps_install link_home gui_env shell_install git_install toolchains_install neovim_install vscodium_install godot_install unity_install claude_install desktop_install security_install llm_install " "$(order macos os_install)"
eq "macos update" "keep_sudo system_update apps_update link_home shell_update toolchains_update neovim_update vscodium_update unity_update claude_update godot_update llm_update " "$(order macos os_update)"
eq "macos uninstall" "unlink_home apps_uninstall neovim_uninstall godot_uninstall unity_uninstall " "$(order macos os_uninstall)"
no "update sets no system settings" grep -qE 'desktop_install|security_install' <<<"$(order macos os_update)"
ok "readme has the mac's steps" grep -q 'brew install gh' "$REPO/README.md"
no "readme no longer says not yet for macos" grep -q '| macOS | Not yet |' "$REPO/README.md"
```

Extend `order`'s name pattern so `system_first` and `gui_env` are stubbed too.

- [ ] **Step 2: Run it to see it fail** — `bash tests/run.sh steps` → `FAIL`

- [ ] **Step 3: Write `macos/steps.sh`**

- [ ] **Step 4: Update `README.md`**

The OS table says `macOS 27 (Apple Silicon) | Done`. "Install" gets a macOS block beside Fedora's:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install gh
gh auth login --web --git-protocol https --scopes admin:public_key,admin:ssh_signing_key
gh repo clone theintonerzero/dotfiles ~/dotfiles
~/dotfiles/install.sh
```

with one line saying to sign in to the App Store first for Xcode. "Commands" says what `dot update` does on each OS. "What you get" marks the Fedora-only rows (System, GNOME, Gaming) and adds a macOS row with the settings from the spec, and says Unity uses VSCodium on macOS. "Changing things" gets a row for each `macos/` list, `shared/firefox-policies.json`, and `fedora/home/<app>/` and `macos/home/<app>/` beside `home/<app>/`. "Undoing an update" says it's Fedora's.

- [ ] **Step 5: Add to `CHANGELOG.md` under Unreleased → Added**, in the file's voice: macOS support and what it brings; config packages per OS; `tests/`.

- [ ] **Step 6: Run everything**

Run: `bash tests/run.sh` → nine `ok` lines, exit 0
Run: shellcheck on every `*.sh`, `bin/dot` and each script under `home/*/.local/bin`, `fedora/home/*/.local/bin` and `macos/home/*/.local/bin` → no output
Run: `/bin/bash -n lib.sh install.sh update.sh uninstall.sh` → no output

- [ ] **Step 7: Commit** — `feat(macos): macos's steps, and the readme and changelog for them`

---

## The backup gate

**Stop here.** Tell Jesse Tasks 1–10 are done and tested in the sandbox, and ask whether the backup is finished. Tasks 11–13 change this Mac. Don't start them on anything less than a clear yes.

---

### Task 11: The first real runs on this Mac

**Files:** whatever the run shows needs fixing; `macos/defaults.txt` (the accent).

This Mac isn't clean: old links in `~` (`~/.gitconfig` and `~/.tmux.conf` point into an older dotfiles folder), oh-my-zsh, fnm, pyenv, and most apps already installed. Where one of those gets in the way, say so and ask before moving it; none of them exists on a fresh Mac.

- [ ] **Step 1: Check the names again.** `brew info --json=v2` for every line of `formulae.txt` and `casks.txt` returns a result. Read `mas help install` for whether it wants `sudo` now, and adjust `system_appstore` if so.

- [ ] **Step 2: Run `./install.sh`** and read all of it. Fix what fails, with a test for each fix where a stub can show it, and run again. If an app won't start for want of Rosetta, add `softwareupdate --install-rosetta --agree-to-license` to `system_install`, run only when `pgrep -q oahd` finds nothing; otherwise Rosetta stays off the Mac.

- [ ] **Step 3: Check each piece**

| Check | Command | Expected |
| --- | --- | --- |
| Formulae and casks | `brew list --formula -1`, `brew list --cask -1` | every line of both lists |
| Links | `readlink -f ~/.config/nvim/init.lua` | a path in the repo |
| Nothing Linux-only | `ls ~/.config/gtk-4.0 ~/.config/environment.d` | no such file |
| Shell | open a new Ghostty window | Starship's prompt; `which nvim codium godot blender` all resolve |
| .NET | `dotnet --version` | `10.` … |
| Python libraries | `python3 -c 'import cv2, numpy, scipy, PIL'` | no output |
| Rust | `cargo --version`, `rustup component list --installed` | has `rust-analyzer`, `rust-src` |
| A setting | `defaults read com.apple.finder ShowPathbar` | `1` |
| The Dock | look | Finder, then the seven in order |
| Dock apps' PATH | `launchctl getenv PATH` | starts with `~/.local/bin` |
| Firefox | `about:policies` in Firefox | uBlock Origin, HTTPS-only and the rest, active |
| Firewall | `/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate` | enabled |
| Godot | double-click a script in a Godot project | a new Ghostty window with Neovim on that file |
| Claude | `claude mcp list` | github, godot-mcp-toolkit, unity, brp, blender, playwright, rea |
| Option as Alt | Alt+S in Claude Code, Alt+C at the prompt | send; fzf's folder picker |
| Hostname | `scutil --get ComputerName` | the name given |

- [ ] **Step 4: Touch ID, with Jesse at the keyboard.** Keep the terminal that ran install open (its sudo is still good, so `sudo rm /etc/pam.d/sudo_local` undoes it). In a **new** terminal: `sudo -k; sudo true` → the Touch ID sheet. Then the same inside tmux.

- [ ] **Step 5: The accent, with Jesse.** In System Settings > Appearance, Jesse picks Graphite and looks at a window's three buttons. Then read what it set: `defaults read -g AppleAccentColor`, `AppleAquaColorVariant`, `AppleHighlightColor`.
  - **Buttons still red, yellow, green:** add those three keys with the values just read to `defaults.txt` under "matching fedora".
  - **Buttons grey:** Jesse switches back to Multicolour; add `NSGlobalDomain AppleAccentColor delete` and `NSGlobalDomain AppleHighlightColor string 0.478431 0.513725 0.509804 Other` (the palette's `#7a8382`).

- [ ] **Step 6: Run `./install.sh` a second time.** Expected: no `==>` line that installs, sets, adds or moves anything; "Left for you" holds only what truly is (signing in to apps, perhaps logging out).

- [ ] **Step 7: Run `./update.sh`.** Expected: it upgrades packages and changes no setting; change one by hand first (`defaults write com.apple.dock tilesize -int 64; killall Dock`) and see it's still 64 after, then run `./install.sh` and see it back at 48.

- [ ] **Step 8: Log out and back in**, then check key repeat, the mouse and tap to click feel as before, and that hidden files show in Finder.

- [ ] **Step 9: Commit** each fix as it's made; the accent as `feat(macos): the accent that matches kanagawa dragon`.

---

### Task 12: Unity, with Jesse's Editor

Needs Jesse: sign in to Unity in the Hub and install an Editor (the repo was checked with 6000.6).

- [ ] **Step 1:** Run `./install.sh` with Unity closed. Expected: `==> ` nothing about Neovim; `defaults read com.unity3d.UnityEditor5.x kScriptsDefaultApp` → `/Applications/VSCodium.app`.
- [ ] **Step 2:** Make an empty project in the Hub, close it, run `unity-project <path>`. Expected: the Pipeline package and the Neovim package in `Packages/manifest.json`; the project opens without package errors in the Console.
- [ ] **Step 3:** In Unity, Settings > External Tools shows VSCodium as the script editor. Double-click a script: VSCodium opens it, at the line when opened from a Console error. Type `transform.` in a `MonoBehaviour`: completion offers its members.
- [ ] **Step 4:** `claude mcp get unity` shows the server; in the project, Claude can read the open scene through it.
- [ ] **Step 5:** `./uninstall.sh` then `./install.sh`: the editor key goes and comes back.

**If Step 2 fails because of the Neovim package:** `unity-project` leaves that package out on macOS (the spec's fallback); add a test for it.
**If Step 3 fails** (no project files for VSCodium, no completion, wrong line): stop and bring it to Jesse with what was seen. The spec makes VSCodium the editor; how far to go to make Unity cooperate is Jesse's call.

- [ ] **Step 6: Commit** any fix: `fix(macos): …`.

---

### Task 13: A clean home, a Fedora check, and handing back

- [ ] **Step 1: Ask Jesse** whether to do one run in a throwaway second user account on this Mac (an empty home folder; Homebrew is shared). If yes: Jesse makes the account, the repo is cloned there, `./install.sh` runs, and Task 11's table is checked again. Fix what only a clean home shows.
- [ ] **Step 2: Fedora in a container**, if Jesse is happy for colima to be started: in a `fedora:44` container with the repo mounted and `stow jq git zsh findutils` installed, `bash tests/run.sh`. Expected: every non-macOS test file `ok`.
- [ ] **Step 3:** `bash tests/run.sh` and the full shellcheck pass once more on the Mac.
- [ ] **Step 4:** Read the README top to bottom against what the Mac now does; fix anything it says that isn't so.
- [ ] **Step 5: Hand back.** Tell Jesse: what was verified here and how; what couldn't be (a truly fresh Mac, unless Step 1 ran; Fedora itself); and that the Fedora machine's next `dot update` will restart itself once after pulling, relink the moved packages, and should end with no `.bak` files and no broken links, which is worth a look when it's run.
