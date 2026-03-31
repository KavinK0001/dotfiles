#!/bin/bash
current=$(hyprctl activeworkspace -j | jq '.id')

if [ "$current" -ge 10 ]; then
    hyprctl dispatch workspace 1
else
    hyprctl dispatch workspace r+1
fi