#!/bin/bash
# space.sh: one workspace's pill: filled when it's the current one, plain when it has windows, and only a
# dim number when it has none. sketchybar says which is current (SELECTED) and, when windows come and go,
# what each workspace holds (INFO), which is kept in a file a workspace until the next time
# shellcheck source=../colors.sh
source "$(dirname "$0")/../colors.sh"

seen=${TMPDIR:-/tmp}/sketchybar-spaces
mkdir -p "$seen"
if [[ ${SENDER:-} == space_windows_change ]]; then
  # every workspace's item hears about every workspace
  [[ $(jq -r '.space // empty' <<<"${INFO:-}" 2>/dev/null) == "$SID" ]] || exit 0
  jq -r '.apps | length' <<<"$INFO" >"$seen/$SID"
fi
windows=$(cat "$seen/$SID" 2>/dev/null) || windows=1

if [[ ${SELECTED:-} == true ]]; then
  sketchybar --set "$NAME" background.drawing=on "background.color=$ACCENT" "label.color=$ON_ACCENT" "label.font=$FONT:Bold:13.0"
elif ((windows > 0)); then
  sketchybar --set "$NAME" background.drawing=on "background.color=$SURFACE" "label.color=$TEXT" "label.font=$FONT:Regular:13.0"
else
  sketchybar --set "$NAME" background.drawing=off "label.color=$DIM" "label.font=$FONT:Regular:13.0"
fi
