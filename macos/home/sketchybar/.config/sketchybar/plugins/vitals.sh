#!/bin/bash
# vitals.sh: how busy the processors are and how full memory is, each red from nine tenths up, and the
# disk only once it's nine tenths full. all three are read here and set in one call, every few seconds
# shellcheck source=../colors.sh
source "${0%/*}/../colors.sh"

# what every process is using, as a share of all the processors
cpu=$(ps -A -o %cpu | awk -v n="$(sysctl -n hw.ncpu)" 'NR > 1 { s += $1 } END { p = int(s / n + 0.5); print (p > 100 ? 100 : p) }')
# memory in use as activity monitor counts it: apps', less what they'd give back, wired and compressed
memory=$(vm_stat | awk -v total="$(sysctl -n hw.memsize)" '
  /page size of/ { for (i = 1; i <= NF; i++) if ($i == "of") size = $(i + 1) }
  /^Anonymous pages/ { used += $NF }
  /^Pages purgeable/ { used -= $NF }
  /^Pages wired down/ { used += $NF }
  /^Pages occupied by compressor/ { used += $NF }
  END { p = int(used * size * 100 / total + 0.5); print (p > 100 ? 100 : p) }')
# the volume your files are on
disk=$(df -k /System/Volumes/Data | awk 'END { sub(/%/, "", $5); print $5 + 0 }')

args=()
if ((cpu >= 90)); then args+=(--set cpu "label=$cpu%" "${ALERT[@]}"); else args+=(--set cpu "label=$cpu%" "${PLAIN[@]}"); fi
if ((memory >= 90)); then args+=(--set memory "label=$memory%" "${ALERT[@]}"); else args+=(--set memory "label=$memory%" "${PLAIN[@]}"); fi
if ((disk >= 90)); then args+=(--set disk drawing=on "label=$disk%" "${ALERT[@]}"); else args+=(--set disk drawing=off); fi
sketchybar "${args[@]}"
