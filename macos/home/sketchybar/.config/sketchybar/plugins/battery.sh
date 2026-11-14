#!/bin/bash
# battery.sh: how full the battery is; red at a fifth or less, green while it charges, and nothing on a
# mac with no battery
# shellcheck source=../colors.sh
source "$(dirname "$0")/../colors.sh"

state=$(pmset -g batt)
percent=$(grep -Eo '[0-9]+%' <<<"$state" | head -n 1)
if [[ -z $percent ]]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi
n=${percent%\%}

# an icon for each tenth
levels="󰁺󰁻󰁼󰁽󰁾󰁿󰂀󰂁󰂂"
if ((n >= 95)); then
  icon="󰁹"
else
  i=$((n / 10 - 1))
  icon=${levels:$((i < 0 ? 0 : i)):1}
fi

if grep -Eq '; (charging|finishing charge)' <<<"$state"; then
  sketchybar --set "$NAME" drawing=on icon="󰂄" label="$percent" "${GOOD[@]}"
elif ((n <= 20)) && grep -q "'Battery Power'" <<<"$state"; then
  sketchybar --set "$NAME" drawing=on icon="$icon" label="$percent" "${ALERT[@]}"
else
  sketchybar --set "$NAME" drawing=on icon="$icon" label="$percent" "${PLAIN[@]}"
fi
