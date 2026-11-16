# C, C++ and C# in Neovim and VSCodium, the gaps: design

Date: 2026-11-16. Status: approved by Jesse in conversation ("approved, go ahead"), with both picks
below as proposed.

## Intent

Jesse asked for C, C++ and C# support in Neovim and VSCodium, not knowing it was already set up:
`pack.cpp` and `pack.cs` in Neovim, the clangd and C# extensions in VSCodium, .NET 10 and a C
compiler on each desktop. What was asked for is then what's missing from that, and four things are.

## Goals

- C# debugging works in Neovim on an Apple Silicon Mac, where Mason's `netcoredbg` is an Intel
  program and there is no Rosetta ("Bad CPU type in executable"). It works in VSCodium there too,
  whose own arm64 `netcoredbg` is installed without its execute bit.
- VSCodium can debug C and C++, on macOS and Fedora.
- CMake is installed on macOS and Fedora, and both editors know its language.
- A `cmake -B build` from the shell writes the `compile_commands.json` clangd reads.
- `dot install` does all of it, a second run does nothing, and `dot update` keeps it so after an
  extension update.

## Non-goals

- Ninja: `make` is on both systems.
- `bear`, for a compile database in a project with a plain Makefile.
- Ubuntu Server, which has neither pack.
- Another C# server for Neovim. It stays `csharp-ls`.

## Anti-goals

- A third-party tap or one person's prebuilt binaries as the debugger's source.
- A build from source inside `dot install`.
- A program left installed that can't run on the machine it's on.

## Constraints

- Homebrew's main repo has no `netcoredbg`, and Mason's registry gives Apple Silicon the Intel build.
- The C# extension's folder has its version in its name, so the debugger's path changes when the
  extension updates.
- Fedora can't be run from this Mac: that side is checked by the tests alone.

## Approaches

An arm64 `netcoredbg` for Neovim on the Mac:

1. **The one VSCodium's C# extension ships (picked).** Samsung's own arm64 release, 3.2.0, and the dotfiles already
   install and update that extension. A step makes it executable, which mends VSCodium's own C#
   debugging as well, and gives Neovim a `netcoredbg` command that runs it. It leans on the
   extension's layout, so the step looks the debugger up each run and says so when it isn't there.
2. Built from source. No dependence on the extension, but a build of several minutes in `dot install`
   that each .NET or Xcode release can break.
3. Prebuilt arm64 binaries from someone's GitHub. Quick, and trust in one person's builds.

A C and C++ debugger for VSCodium:

1. **CodeLLDB, `vadimcn.vscode-lldb` (picked).** The debugger Neovim already uses, and one line in
   one list for both systems.
2. LLDB DAP, LLVM's own extension. The clangd extension's publisher and Xcode's `lldb-dap`, but
   Fedora would need the `lldb` package too.

## The design

- **The debugger step.** On an Apple Silicon Mac, after VSCodium's extensions are installed or
  updated: find the newest C# extension's `.debugger/netcoredbg/netcoredbg`, make it executable, keep
  a copy of its folder in `~/.local/opt/netcoredbg`, and put a `netcoredbg` command in `~/.local/bin`
  that runs the copy. A copy, as VSCodium updates the extension by itself into a new folder, and a
  script, as the debugger looks for its library beside the path it's started by. `dot uninstall` removes the command.
  With no extension or no debugger in it, the step says what's missing and goes on.
- **Neovim.** On an Apple Silicon Mac Mason doesn't install `netcoredbg`, and the `coreclr` adapter
  runs the command above. Everywhere else nothing changes: Mason's build runs on Fedora.
- **CMake.** `cmake` in `macos/formulae.txt` and `fedora/packages.txt`; `pack.cmake` in Neovim, off
  on a server; `ms-vscode.cmake-tools` in VSCodium.
- **The compile database.** `CMAKE_EXPORT_COMPILE_COMMANDS=ON` in `.zshenv`. Both editors' CMake
  plugins already ask for it themselves.
- **Tests and docs.** The pack and extension lists in `tests/`, a test for the debugger step, the
  README's counts (18 packs, 20 extensions) and rows, and the changelog.

## Left to the builder

- Whether the `netcoredbg` command is a link or a small script; it has to find the libraries beside
  the real program.
- How Neovim's adapter is overridden, and how Mason's two lists (the tools and the debug adapters)
  are kept from installing the Intel build.

## How it's checked

A debug session run to a breakpoint from headless Neovim on this Mac, in a small C# app and a small C
program, and the repo's tests. If the extension's debugger doesn't work against .NET 10, the work
stops and goes back to Jesse.
