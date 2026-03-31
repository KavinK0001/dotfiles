#!/bin/bash
current=$(hyprctl activeworkspace -j | jq '.id')

if [ "$current" -ge 10 ]; then
    hyprctl dispatch workspace 1
elif [ "$current" -lt 9 ]; then
    hyprctl dispatch workspace r+1
fi