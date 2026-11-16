# C, C++ and C# Gaps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** C# debugging works in Neovim and VSCodium on an Apple Silicon Mac, VSCodium debugs C and C++, and CMake is installed and known to both editors.

**Architecture:** The lists gain CMake, `pack.cmake` and two extensions. A step in `shared/vscodium.sh` mends the C# extension's debugger and keeps a copy of it in `~/.local/opt/netcoredbg`, with a `netcoredbg` script in `~/.local/bin`; on an Apple Silicon Mac Neovim's `coreclr` adapter runs that command and Mason no longer installs its Intel build.

**Tech Stack:** bash, AstroNvim v6 (lazy.nvim, mason-tool-installer, nvim-dap), VSCodium with Open VSX, Homebrew, dnf.

**Spec:** `docs/superpowers/specs/2026-11-16-c-family-gaps-design.md`

## Global Constraints

- No third-party tap, no build from source, no binaries from anywhere but what the dotfiles already install.
- Fedora, Ubuntu Server and an Intel Mac behave exactly as they do now, but for CMake, `pack.cmake` and the two extensions on Fedora.
- "An Apple Silicon Mac" is `os_id` = `macos` with `uname -m` = `arm64` in bash, and `vim.fn.has "mac" == 1` with `vim.uv.os_uname().machine == "arm64"` in Lua.
- The debugger's source is `~/.vscode-oss/extensions/muhammad-sammy.csharp-*/.debugger/netcoredbg/`, its copy `~/.local/opt/netcoredbg/`, its command `~/.local/bin/netcoredbg`.
- Repo conventions: list files with `#` comments read by `list`; `say`/`warn`/`todo`; plain lowercase comments; a failing test before each change; shellcheck-clean; conventional commits ending with the attribution line. Commits wait for Jesse's word.

## Review Focus

1. **VSCodium updates the C# extension by itself, between two `dot` runs:** the old folder is gone and the new debugger has no execute bit; Neovim's debugger still runs, as it's a copy, and the next `dot update` mends VSCodium's and refreshes the copy.
2. **Two versions of the extension side by side,** as VSCodium leaves mid-update: the newer one's debugger is used.
3. **No debugger to find** (no C# extension, or one whose debugger didn't download): a warning that names it, and the run carries on; in Neovim, starting a C# debug session says to run `dot install`, not a bare ENOENT.
4. **A second run:** no copy, no `chmod`, no write, nothing said.
5. **A `~/.local/bin/netcoredbg` that is your own file,** not the dotfiles' script: left as it is, by install and by uninstall.

---

### Task 1: CMake, and the two extensions

**Files:** Modify `macos/formulae.txt`, `fedora/packages.txt`, `shared/vscodium-extensions.txt`, `home/nvim/.config/nvim/lua/community.lua`, `home/zsh/.zshenv`, `README.md`, `CHANGELOG.md`. Test: `tests/test_nvim.sh`, `tests/test_vscodium.sh`, `tests/test_macos_apps.sh`, `tests/test_home.sh`.

- [ ] **Step 1: Failing tests.**
  - `test_nvim.sh`: the desktop's list has `pack.cmake` straight after `pack.cpp`; the server's list is unchanged.
  - `test_vscodium.sh`: `vadimcn.vscode-lldb` and `ms-vscode.cmake-tools` are lines of `shared/vscodium-extensions.txt`.
  - `test_macos_apps.sh`: `cmake` is listed in `macos/formulae.txt`. `test_vscodium.sh` (it runs everywhere): `cmake` is listed in `fedora/packages.txt`.
  - `test_home.sh`: `zsh -f -c "source .zshenv; print \$CMAKE_EXPORT_COMPILE_COMMANDS"` prints `ON`.
- [ ] **Step 2: Run** `bash tests/run.sh nvim vscodium macos_apps home` — expected: FAIL.
- [ ] **Step 3: Implement.** `cmake` beside the other toolchains in both lists; `{ "pack.cmake", false }` after `pack.cpp`; the two extension ids after the clangd and C# ones; `export CMAKE_EXPORT_COMPILE_COMMANDS=ON` in `.zshenv` with a comment saying what reads the file.
- [ ] **Step 4: Run** `bash tests/run.sh` — expected: all `ok`.
- [ ] **Step 5: README and changelog.** README: Toolchains gains CMake; Neovim says 18 language packs; VSCodium says 20 extensions and names the two debuggers. Changelog, under Unreleased/Added.
- [ ] **Step 6: Commit** `feat: cmake, with its language in both editors, and a c and c++ debugger in vscodium`.

### Task 2: The C# debugger step

**Files:** Modify `shared/vscodium.sh`, `macos/steps.sh`. Test: `tests/test_vscodium.sh`, `tests/test_steps.sh`.

**Interfaces:**
- Produces `vscodium_netcoredbg` (no arguments; called last in `vscodium_install` and `vscodium_update`, after their `have codium` check). Off an Apple Silicon Mac it does nothing. Otherwise: picks the newest `netcoredbg` program under the source glob (by `-nt`); makes it executable when it isn't; when it differs from the copy's (`cmp -s`), replaces `~/.local/opt/netcoredbg/` with a copy of its folder, built beside it as `netcoredbg.new` and moved into place; writes `~/.local/bin/netcoredbg`, a script that runs the copy's program, unless something is at that path already (a script and not a link: started through a link, the debugger looks for its library beside the link). None found: `warn`, return 0.
- Produces `vscodium_uninstall`: removes `~/.local/bin/netcoredbg` when it is that script, byte for byte, and `~/.local/opt/netcoredbg`. Added to macOS's `os_uninstall` after `neovim_uninstall`.
- Task 3 consumes the path `~/.local/bin/netcoredbg`.

- [ ] **Step 1: Failing tests** in `test_vscodium.sh`, each in a subshell with `load macos`, a `uname` stub that answers `-m` with `arm64` and `-s` with `Darwin`, and a made-up extension folder holding a `netcoredbg` script (mode 644, printing its version) and a `libdbgshim.dylib` file:
  - after the step: the source is executable; `~/.local/opt/netcoredbg/netcoredbg` is executable and `cmp`-equal to it; the dylib is copied; `~/.local/bin/netcoredbg` runs, finds its library, and is no link.
  - a second run prints nothing and leaves the copy's inode as it was.
  - with a second, newer extension folder (`touch -t`), the copy is the newer one's.
  - with the extension folder deleted after a run, `~/.local/bin/netcoredbg` still runs; the step warns and returns 0.
  - with no extension at all: a warning naming the C# extension, return 0, no `~/.local/opt/netcoredbg`.
  - with `~/.local/bin/netcoredbg` a regular file of your own: left byte for byte, by the step and by `vscodium_uninstall`.
  - `uname -m` answering `x86_64`, and `load fedora`: nothing is made.
  - `vscodium_uninstall` after a run removes the link and the copy.
  - `vscodium_install` and `vscodium_update`, with a `codium` stub, each run the step (the copy exists afterwards).
  - `test_steps.sh`: macOS's uninstall order is `unlink_home apps_uninstall bar_uninstall neovim_uninstall vscodium_uninstall godot_uninstall unity_uninstall`.
- [ ] **Step 2: Run** `bash tests/run.sh vscodium steps` — expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `bash tests/run.sh` — expected: all `ok`.
- [ ] **Step 5: Commit** `fix(macos): c#'s debugger runs on apple silicon, in vscodium and as a command of its own`.

### Task 3: Neovim uses it

**Files:** Create `home/nvim/.config/nvim/lua/plugins/csharp.lua`. Modify `home/nvim/.config/nvim/lua/plugins/mason.lua`, `shared/neovim.sh`, `README.md`, `CHANGELOG.md`. Test: `tests/test_nvim.sh`, `tests/test_shared.sh`.

**Interfaces:**
- Consumes `~/.local/bin/netcoredbg` from Task 2.
- `plugins/mason.lua`: on an Apple Silicon Mac, `netcoredbg` is taken out of `ensure_installed` (mason-nvim-dap's own list is unused in AstroNvim v6, so this one list is all).
- `plugins/csharp.lua`: returns `{}` off an Apple Silicon Mac. On one, a spec for `mfussenegger/nvim-dap` whose `config` sets `dap.adapters.coreclr` to a function that hands nvim-dap `{ type = "executable", command = <home>/.local/bin/netcoredbg, args = { "--interpreter=vscode" } }`, or, when that isn't executable, warns "run dot install" and starts nothing; and, where `dap.configurations.cs` is unset, gives `cs` and `fsharp` mason-nvim-dap's own `coreclr` configurations.
- `shared/neovim.sh`: `neovim_netcoredbg`, called from `neovim_install` and `neovim_update` after the Mason installs: on an Apple Silicon Mac with `${XDG_DATA_HOME:-~/.local/share}/nvim/mason/packages/netcoredbg` there, `nvim --headless "+MasonUninstall netcoredbg" +qa`, a failure a `warn`.

- [ ] **Step 1: Failing tests.**
  - `test_nvim.sh`, with `vim.fn.has` and `vim.uv.os_uname` standing in for each machine: on arm64 macOS a desktop's tools, given `netcoredbg` among them, come out without it; on x86_64 macOS and on Linux, with it. `csharp.lua` is `{}` on Linux and on x86_64 macOS, and one spec named `mfussenegger/nvim-dap` on arm64 macOS; its `config`, run against a stand-in `dap` and a home with an executable `.local/bin/netcoredbg`, leaves an adapter that hands back that command with `--interpreter=vscode`, and `cs` configurations; against a home without it, the adapter hands nothing back and a warning names `dot install`.
  - `test_shared.sh`: with the Mason folder there, an `nvim` stub and arm64 macOS, `neovim_netcoredbg` calls `nvim --headless +MasonUninstall netcoredbg +qa`; without the folder, on x86_64, or on Fedora, it doesn't.
- [ ] **Step 2: Run** `bash tests/run.sh nvim shared` — expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `bash tests/run.sh` — expected: all `ok`.
- [ ] **Step 5: README and changelog:** the Neovim and VSCodium rows say where C#'s debugger comes from on a Mac; changelog under Unreleased, in a Fixed section.
- [ ] **Step 6: Commit** `fix(neovim): c# debugging on apple silicon, with the debugger vscodium's extension brings`.

### Task 4: On this Mac

- [ ] **Step 1: Apply,** as `dot install` would, the steps this touches and no others: `brew install cmake`, `neovim_install`, `vscodium_install`.
- [ ] **Step 2: C#.** A console app in the scratchpad, built with `dotnet build`; from headless Neovim, a breakpoint on a line, the `cs` configuration with `program` set to the built dll, and the session stops there with a local's value readable. If the debugger can't do this against .NET 10, stop and go back to Jesse.
- [ ] **Step 3: C.** The same with a C program built with `clang -g` and the `codelldb` adapter.
- [ ] **Step 4: CMake.** In a scratch project, `cmake -B build` from a zsh that has read `.zshenv` writes `build/compile_commands.json`; a `CMakeLists.txt` opened in Neovim has the `cmake` parser.
- [ ] **Step 5: VSCodium.** `codium --list-extensions` has both new extensions and nothing the list doesn't name.
- [ ] **Step 6: Run** `bash tests/run.sh` — expected: all `ok`; shellcheck clean on every script touched.
