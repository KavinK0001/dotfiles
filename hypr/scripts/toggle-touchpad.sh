#!/usr/bin/env bash
STATE=/home/deadeyegam/.config/hypr/touchpad_state
DEVICE="dell0a2b:00-06cb:cdd6-touchpad"   # replace with output from: hyprctl devices

if [ "$(cat $STATE 2>/dev/null)" = "0" ]; then
  hyprctl keyword device[$DEVICE]:enabled true
  echo 1 > $STATE
else
  hyprctl keyword device[$DEVICE]:enabled false
  echo 0 > $STATE
fi
