#!/usr/bin/env bash
# Cycles the default PulseAudio/PipeWire sink to the next available one
# and moves all currently playing streams to it.

sinks=($(pactl list short sinks | awk '{print $1}'))
count=${#sinks[@]}

if [[ $count -lt 2 ]]; then
    exit 0  # Nothing to switch to
fi

current=$(pactl get-default-sink)
current_index=-1

for i in "${!sinks[@]}"; do
    sink_name=$(pactl list short sinks | awk -v id="${sinks[$i]}" '$1==id {print $2}')
    if [[ "$sink_name" == "$current" ]]; then
        current_index=$i
        break
    fi
done

next_index=$(( (current_index + 1) % count ))
next_sink_name=$(pactl list short sinks | awk -v id="${sinks[$next_index]}" '$1==id {print $2}')

pactl set-default-sink "$next_sink_name"

# Move all active sink inputs to the new default sink
pactl list short sink-inputs | awk '{print $1}' | while read -r input; do
    pactl move-sink-input "$input" "$next_sink_name"
done