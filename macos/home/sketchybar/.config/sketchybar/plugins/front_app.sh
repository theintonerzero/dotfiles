#!/bin/bash
# front_app.sh: the name of the app in front
if [[ ${SENDER:-} == front_app_switched ]]; then sketchybar --set "$NAME" label="${INFO:-}"; fi
