#!/bin/bash
# spotify.sh: what spotify is playing, while it plays. spotify says so itself each time that changes, as
# json in INFO; what it names is only ever text handed to sketchybar, never run
# shellcheck source=../colors.sh
source "$(dirname "$0")/../colors.sh"

export LC_ALL=en_US.UTF-8

if [[ ${SENDER:-} != spotify_change ]]; then
  # a look every so often: spotify says nothing as it quits
  pgrep -xq Spotify || sketchybar --set "$NAME" drawing=off
  exit 0
fi

state=$(jq -r '."Player State" // empty' <<<"${INFO:-}" 2>/dev/null) || state=""
if [[ $state != Playing ]]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi
artist=$(jq -r '.Artist // empty' <<<"$INFO")
track=$(jq -r '.Name // empty' <<<"$INFO")
text=$artist
if [[ -n $artist && -n $track ]]; then text="$artist · $track"; elif [[ -n $track ]]; then text=$track; fi
if ((${#text} > 32)); then
  text=${text:0:31}
  text="${text%% }…"
fi
sketchybar --set "$NAME" drawing=on label="$text" "${PLAIN[@]}"
