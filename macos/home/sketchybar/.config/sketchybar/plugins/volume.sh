#!/bin/bash
# volume.sh: there only while sound is muted, or turned all the way down
# shellcheck source=../colors.sh
source "$(dirname "$0")/../colors.sh"

# sketchybar hands over the new volume when it changes, 0 for muted; as the bar starts, macos is asked
if [[ ${SENDER:-} == volume_change ]]; then
  volume=${INFO:-}
else
  volume=$(osascript -e 'set v to get volume settings' -e 'if output muted of v then return 0' -e 'return output volume of v' 2>/dev/null)
fi
if [[ $volume == 0 ]]; then
  sketchybar --set "$NAME" drawing=on icon="󰝟" label=muted "${ALERT[@]}"
else
  sketchybar --set "$NAME" drawing=off
fi
