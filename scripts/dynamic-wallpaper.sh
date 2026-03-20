#!/bin/bash
# 47 Industries - Dynamic Wallpaper (macOS-style time-of-day shift)
# Adjusts screen warmth based on time — subtle and automatic

while true; do
    HOUR=$(date +%H)
    DISPLAY_NAME=$(xrandr --query 2>/dev/null | grep " connected" | head -1 | cut -d" " -f1)
    [ -z "$DISPLAY_NAME" ] && sleep 300 && continue

    if [ "$HOUR" -ge 21 ] || [ "$HOUR" -lt 6 ]; then
        # Night: warm + slightly dim
        xrandr --output "$DISPLAY_NAME" --gamma 1.0:0.88:0.76 --brightness 0.9 2>/dev/null
    elif [ "$HOUR" -ge 18 ]; then
        # Evening: slightly warm
        xrandr --output "$DISPLAY_NAME" --gamma 1.0:0.93:0.85 --brightness 0.95 2>/dev/null
    elif [ "$HOUR" -ge 7 ]; then
        # Day: normal
        xrandr --output "$DISPLAY_NAME" --gamma 1.0:1.0:1.0 --brightness 1.0 2>/dev/null
    else
        # Early morning: slightly warm
        xrandr --output "$DISPLAY_NAME" --gamma 1.0:0.95:0.88 --brightness 0.95 2>/dev/null
    fi

    sleep 300  # Check every 5 minutes
done
