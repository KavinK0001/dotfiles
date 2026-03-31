#!/bin/bash
current=$(hyprctl activeworkspace -j | jq '.id')

if [ "$current" -le 1 ]; then
    hyprctl dispatch workspace 10
else
    hyprctl dispatch workspace r-1
fi