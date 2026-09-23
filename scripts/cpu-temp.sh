#!/bin/bash

# A sample script for pill bar's custom module
# CPU Temperature output example (JSON):
#   {'icon': '', 'color': '#dbb652', 'text': '67°C', 'tooltip': '67°C CPU Temperature'}

if command -v sensors>/dev/null; then
  raw=$(sensors | grep Core | tail -n 1 | awk '{print $3}')
  unit=$([[ "$raw" == *"F"* ]] && echo "°F" || echo "°C")
  value=$(echo "$raw" | awk '{gsub(/\+|°C|°F/,""); print $0}' | awk -F '.' '{print $1}')
else
  unit="lm_sensors not installed."
  value=""
fi

if [ "$value" -gt 80 ]; then
  color="#db7552"
  icon=""
elif [ "$value" -gt 60 ]; then
  color="#dbb652"
  icon=""
else
  color="#6d9fd7"
  icon=""
fi

printf '{"icon": "%s", "color": "%s", "text": "%s%s", "tooltip": "%s%s CPU Temperature"}' "$icon" "$color" "$value" "$unit" "$value" "$unit"
