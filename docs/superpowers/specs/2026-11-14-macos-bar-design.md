# A status bar for macOS: design

Date: 2026-11-14. Status: approved by Jesse in conversation ("I like the pro black + pills", then "yeah
alright", with the wallpaper as a default).

## Intent

macOS's menu bar is the one part of the screen that doesn't look like the rest of this setup. A
sketchybar bar replaces it: minimal, in the same pills and Kanagawa Dragon colours as tmux and the
prompt, with good information on it and nothing else. It is a Mac-only extra Jesse asked for by name;
a tiling window manager with its own workspaces is to follow, as a separate piece of work.

## Goals

- `dot install` on macOS leaves the bar running, Apple's menu bar hidden until the pointer reaches the
  top edge, and Pro Black as the wallpaper. A second run does nothing.
- Always shown: the workspaces, with the current one filled; the front app; the battery; the date; the
  time, on a 24-hour clock.
- Shown only when there is something to say: what Spotify is playing; that sound is muted; that there
  is no Wi-Fi; a low battery, in red; a charging one, in green.
- `dot update` updates sketchybar with the rest of Homebrew's formulae. `dot uninstall` stops the bar
  and brings Apple's menu bar back.

## Non-goals

- Anything to click: no menus, popups or buttons. See Constraints.
- The menu bar's icons (Vesktop, Steam and the rest). They are on Apple's bar, one push of the pointer
  away.
- CPU, memory, network speed, weather, calendar.
- The tiling window manager. The bar's workspace items are written so that its workspaces can replace
  macOS's own spaces later, and no more than that.
- Fedora. GNOME's top bar is its counterpart.

## Anti-goals

- A bar that breaks when a known macOS 27 bug is hit.
- Trusting the whole third-party tap. Only the one formula is trusted.
- Apple's wallpaper image copied into this repo.

## Constraints

- sketchybar is in no Homebrew main repo: it comes from its author's tap, `FelixKratz/formulae`, which
  Jesse approved for this. Homebrew loads a tap's formula only once it is trusted (`brew trust`).
- sketchybar 2.24.1 on macOS 27 has open bugs (its issues 850, 852 and 849, read on 2026-11-14): on
  27.2, on a display with a notch and an auto-hidden menu bar, a click on the bar brings Apple's bar
  down and never reaches the item; items that mirror menu-bar icons stay blank; and on 27.0 a click on
  an empty part of the bar raises the bar's background over its items. So nothing on the bar is
  clickable, nothing mirrors a menu-bar icon, and the bar's own background is fully transparent, which
  leaves nothing to cover the items.
- It was checked on this Mac (macOS 27.0.1, built-in display with a notch) on 2026-11-14 that
  sketchybar 2.24.1 starts, answers queries, and draws pills in JetBrains Mono Nerd Font.
- Pro Black is not on a fresh macOS as a full image: macOS downloads it when it is first chosen in
  System Settings.
- The repo's conventions hold: list files, idempotent steps, `say`/`warn`/`todo`, tests first,
  shellcheck-clean, conventional commits.

## Approaches

1. **Plugins as small shell scripts, sketchybar's own way** (chosen). One script an item, each of
   which the test suite can run with stand-ins for `sketchybar`, `pmset` and the rest. No new
   dependency.
2. **SbarLua, a Lua config.** Tidier for a large bar with animation; it needs a second thing built
   from source, and this bar is seven small items.
3. **A helper daemon in C** for event-driven items with no polling. Far more than this needs.

Jesse left the how to me; 1 is my call.

## The design

- **Look.** Option A of the mock-ups: a 32-point bar with a fully transparent background; items are
  pills 22 points high in the surface colour (`#282727`) with text in `#c5c9c5`, JetBrains Mono Nerd
  Font at 13 points; the current workspace is the one pill filled with the accent (`#7a8382`, text
  `#0d0c0c`, bold), a workspace with no windows has no pill and dim text; an item with bad news is a
  red pill (`#c4746e`, dark bold text); a charging battery has green text (`#87a987`); the time is
  bold. Workspaces and the front app are on the left, the rest on the right, the time outermost. The
  colours are in one file, named as the prompt's palette names them.
- **Workspaces** are macOS's own spaces for now, numbered.
- **Now playing** is Spotify's alone: it announces its own track changes, which sketchybar can listen
  for; what other players are doing is not reliably readable on recent macOS.
- **Apple's menu bar** is set to hide and show automatically, on the desktop and in full screen.
- **Wallpaper.** Pro Black, where macOS has the image. Where it doesn't, plain black, and a line at
  the end of install saying to choose Pro Black once in System Settings so that macOS fetches it.
  Set by `dot install` only, as macOS's other settings are.
- **In the dotfiles.** `macos/taps.txt` names the tap and the formula trusted from it; `sketchybar`
  joins `macos/formulae.txt`; the config is a package only macOS links
  (`macos/home/sketchybar/.config/sketchybar/`); `macos/bar.sh` starts the bar at login as a Homebrew
  service and reloads it when its config changes.

### Calls made (mine, not Jesse's)

- Approach 1.
- Battery is "low" at 20% or less while not charging.
- "No Wi-Fi" means the Wi-Fi interface has no network, whatever the reason.
- The date reads as `Sat 14 Nov`.
- On a display with no notch the layout is the same: pills at the two edges.
- Up to ten spaces get an item.

## Testing

- Sandbox tests, as for the rest of macOS: the tap and trust step is idempotent and trusts only the
  formula; the service starts once; each plugin script sets what it should for each state it can be
  in (playing or not, muted or not, Wi-Fi or none, battery low, charging, plain); the wallpaper step
  on each side of "the image is there"; uninstall stops the bar and unhides Apple's.
- On this Mac: the bar run from the branch's config, looked at in a screen capture in the quiet and
  busy states, and after a click on an empty part of it.

## Left to the builder

- The plugins' file names and how they share the colours.
- How "no Wi-Fi" and "muted" are read on macOS 27.
- Which `defaults` keys hide the menu bar on macOS 27, found by trying them on this Mac.
- README and CHANGELOG wording.
