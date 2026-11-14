#!/bin/bash
# clock.sh: the time, on a 24-hour clock, and the date beside it
sketchybar --set clock label="$(date +%H:%M)" --set date label="$(date '+%a %-d %b')"
