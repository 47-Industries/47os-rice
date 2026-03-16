#!/usr/bin/env bash

STEP=5

# Find backlight device, fall back to first available
DEVICE=$(brightnessctl --list 2>/dev/null | awk -F"'" '/backlight/ {print $2; exit}')
if [ -z "$DEVICE" ]; then
    DEVICE=$(brightnessctl --list 2>/dev/null | awk -F"'" 'NR==1 {print $2; exit}')
fi

if [ -z "$DEVICE" ]; then
    notify-send "Brightness" "No backlight device found"
    exit 1
fi

case "$1" in
  up)
    brightnessctl -d "$DEVICE" set "${STEP}%+" > /dev/null
    ;;
  down)
    brightnessctl -d "$DEVICE" set "${STEP}%-" > /dev/null
    ;;
esac

# Get current brightness percentage - extract from (XX%) pattern
PERCENT=$(brightnessctl -d "$DEVICE" 2>/dev/null | grep -oP '\(\K[0-9]+(?=%\))')

if [ -n "$PERCENT" ]; then
    notify-send -h "int:value:$PERCENT" \
                -h string:x-canonical-private-synchronous:brightness \
                "Brightness" "${PERCENT}%"
fi
