#!/bin/bash
# network.sh: there only while this mac has no way out to a network
# shellcheck source=../colors.sh
source "$(dirname "$0")/../colors.sh"

if route -n get default >/dev/null 2>&1; then
  sketchybar --set "$NAME" drawing=off
else
  sketchybar --set "$NAME" drawing=on icon="󰖪" label=offline "${ALERT[@]}"
fi
