#!/bin/bash
workspace=$(hyprctl activewindow -j | jq -r '.workspace.name')
if [[ "$workspace" == "special:magic" ]]; then
    hyprctl dispatch movetoworkspace e+0
    hyprctl dispatch settiled
else
    hyprctl dispatch movetoworkspace special:magic
    hyprctl dispatch setfloating
    hyprctl dispatch resizeactive exact 70% 70%
fi
