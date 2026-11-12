# How I work

## Before building

- When a request leaves real choices open (scope, behaviour, the look, the data), ask focused
  questions before writing code, several at once if that's what it takes, and say which
  assumptions you are making.
- For anything bigger than a small fix, agree on the design with me first, then build it.

## Commits

- Conventional commits: `feat(scope): …`, `fix: …`, `docs: …`, `test: …`, `refactor: …`,
  `chore: …`.

## Design

- UI mockups and front-end polish go through impeccable (the `impeccable` plugin).
- I prefer GNOME and libadwaita apps, such as Nautilus, over KDE and Qt ones.

## Unity

- Use the Unity Editor I have installed (`unity editors --installed`), not the newest LTS, unless I
  say otherwise. Ask before installing another Editor or module.
- Run `unity-project` in every Unity project, new or existing, before Unity opens it: it adds
  Unity's Pipeline package, which the `unity` CLI and MCP server drive the Editor through, and the
  Neovim package, and sets the Editor and Linux builds to Vulkan only.
- Keep the Editor open and drive it with the `unity` CLI. Check gameplay in Play mode with
  simulated input, Game view captures and the console before calling it done. Build for Linux
  (StandaloneLinux64).

## This machine

- Fedora Workstation with GNOME.
- Packages come from dnf: Fedora's repos, then RPM Fusion and COPR. Avoid Flathub unless I ask
  for it.
- Toolchains: mise for Node, Go, Java and the like, rustup for Rust, uv for Python.
- My dotfiles are in `~/dotfiles`, managed by its `dot` command
  (`dot install`, `dot update`, `dot uninstall`). The config files in `~` are links into it, so
  change them in the repo.
