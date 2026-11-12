---
name: unity-workflow
description: Use for any work in a Unity project or on a game made with Unity on this machine (creating or opening a project, writing scripts, building scenes, play-testing, fixing bugs, making a Linux build), before Unity's own new-unity-project or unity-cli skills act. Says which Editor to use, how to set a project up with unity-project (Pipeline package, Neovim, Vulkan), and how to check a game in Play mode and build it for Linux.
---

# Unity on this machine

These dotfiles installed Unity Hub, the `unity` CLI, Claude's `unity` MCP server and Unity's plugin.
Where Unity's skills say otherwise, this skill wins. Leave out the `--caller` and `--skill` flags
Unity's skills add: they only label calls for Unity's analytics, which these dotfiles turn off.

## Before anything

- `unity auth status --format json`: not signed in? Ask the user to sign in (Unity Hub, or
  `unity auth login`). The Editor's licence needs it.
- `unity editors --installed --format json`: use the newest **installed** Editor, not the latest LTS.
  None installed? Stop and ask. These dotfiles were checked with Unity 6.6 (6000.6); offer that line,
  or `unity install lts` if the user wants LTS. Never install an Editor or module without a yes, as
  each is several GB. A new Editor's terms need accepting once (`unity terms accept <version>`, after
  the user agrees, or in its first-run dialog).

## A new project

1. Pick a template from `unity templates --editor-version <version> --type core --format json`
   (`com.unity.template.urp-blank` for 3D, `com.unity.template.universal-2d` for 2D).
2. `unity projects create "<Name>" --path <parent> --editor-version <version> --template <id> --no-cloud`
3. Run **`unity-project "<full project path>"`** in place of `unity pipeline install`, and before
   Unity opens it. It adds the Pipeline package (the CLI and MCP server drive the Editor through it) and
   the Neovim package, and sets the Editor and Linux builds to Vulkan only. Run it in an existing
   project too, before working in it.
4. Git: `git init -b main`, Unity's `.gitignore`, Git LFS for large binary assets, as Unity's
   unity-cli skill shows.
5. `unity open "<full project path>" --until-ready`. Pass `--project-path "<full project path>"` to
   every command that reaches the Editor from then on.

## Building the game

- Write C# with the file tools: one MonoBehaviour per file, named after its class. Then
  `unity recompile --project-path <path> --format json` and fix every error **and warning**: Unity
  6.6+ deprecates APIs that older examples use, such as `FindObjectsSortMode`.
- Input: projects use the Input System package (`Keyboard.current`, `Mouse.current`), not
  `UnityEngine.Input`.
- Build scenes in the live Editor with `unity command script eval` or the MCP tools, never by
  editing `.unity` or `.prefab` YAML. Save the scene and add it to the build settings.

## Checking it works

Before calling a feature done:

1. Keep the Editor ticking while it isn't focused, which is the normal case when you drive it:
   `unity command editor set_auto_tick`, then `unity command editor.playmode set_run_in_background`.
   `editor.playmode start` alone leaves the game stuck at its first frame, and captures stale.
2. `unity command editor.playmode start`, then confirm frames advance
   (`unity command job wait -- --condition '{"member":"UnityEngine.Time.frameCount","op":"changed"}' --timeout 10`).
3. Drive it with simulated input (`runtime simulate_key`: `down`, wait, `up`).
4. Capture the Game view (`capture game_view` with an `output-path`) and look at it; show it to the
   user.
5. Read the console (`console get`, level `warn`) and fix what it reports.
6. Leave Play mode, and turn Run in Background off again
   (`unity command editor.playmode set_run_in_background -- --enabled false`). When you're done
   driving the Editor, turn auto-tick off too (`unity command editor set_auto_tick -- --enabled false`).
   The Pipeline package takes `--enabled`; Unity's own skill still shows the old `--enable`, which it
   refuses.

Unity's unity-cli skill has the full loop, in `references/playmode-verification-loop.md`.

## A Linux build

`unity build` refuses a project that is open in an Editor. With it open, build from the Editor:

```bash
unity command script eval --project-path "<path>" --timeout 900 \
  'var r = UnityEditor.BuildPipeline.BuildPlayer(new UnityEditor.BuildPlayerOptions {
     scenes = new[] { "Assets/Scenes/Main.unity" }, locationPathName = "<path>/Build/<Name>.x86_64",
     target = UnityEditor.BuildTarget.StandaloneLinux64 });
   return r.summary.result + " errors=" + r.summary.totalErrors;'
```

The player runs on Vulkan: its `-logFile` shows `Vulkan API version`. Offer to launch it for the
user.

## Neovim

Unity opens scripts in Neovim, in Ghostty, through the Neovim package. The `.sln` that `csharp-ls`
reads regenerates when Unity gets focus, or with
`unity command script eval 'Unity.CodeEditor.CodeEditor.CurrentEditor.SyncAll(); return "ok";'`.
