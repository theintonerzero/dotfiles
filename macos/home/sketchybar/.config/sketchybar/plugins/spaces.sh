#!/bin/bash
# spaces.sh: every workspace's pill, dressed in one call: filled when it's the current one, plain when it
# has windows, and only a dim number when it has none. sketchybar says which are current when you switch
# (space_change) and what a workspace holds when its windows come and go (space_windows_change); each is
# kept in a small file until the next time. this runs on every switch, so it starts no other program:
# the pills would lag behind the switch by as long as those took
# shellcheck source=../colors.sh
source "${0%/*}/../colors.sh"

seen=${TMPDIR:-/tmp}/sketchybar-spaces
[[ -d $seen ]] || mkdir -p "$seen"

a_space='"space":[[:space:]]*([0-9]+)'
no_apps='"apps":[[:space:]]*\{[[:space:]]*\}'
a_current=':[[:space:]]*([0-9]+)'
case ${SENDER:-} in
  space_windows_change)
    if [[ ${INFO:-} =~ $a_space ]]; then
      n=${BASH_REMATCH[1]}
      if [[ $INFO =~ $no_apps ]]; then echo 0 >"$seen/$n"; else echo 1 >"$seen/$n"; fi
    fi
    ;;
  space_change)
    # one current workspace a display
    now="" rest=${INFO:-}
    while [[ $rest =~ $a_current ]]; do
      now+="${BASH_REMATCH[1]} "
      rest=${rest#*"${BASH_REMATCH[0]}"}
    done
    echo "$now" >"$seen/current"
    ;;
esac

current=""
if [[ -f $seen/current ]]; then read -r current <"$seen/current"; fi
args=()
for n in 1 2 3 4 5 6 7 8 9 10; do
  windows=1
  if [[ -f $seen/$n ]]; then read -r windows <"$seen/$n"; fi
  if [[ " $current " == *" $n "* ]]; then
    args+=(--set "space.$n" background.drawing=on "background.color=$ACCENT" "label.color=$ON_ACCENT" "label.font=$FONT:Bold:13.0")
  elif [[ $windows != 0 ]]; then
    args+=(--set "space.$n" background.drawing=on "background.color=$SURFACE" "label.color=$TEXT" "label.font=$FONT:Regular:13.0")
  else
    args+=(--set "space.$n" background.drawing=off "label.color=$DIM" "label.font=$FONT:Regular:13.0")
  fi
done
sketchybar "${args[@]}"
