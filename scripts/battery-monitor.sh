#!/bin/bash
# 47 Industries - Low Battery Monitor
# Runs in background, checks battery every 60 seconds
# Only active on laptops (exits immediately on desktops)

BATTERY_PATH=""
for ps in /sys/class/power_supply/BAT*; do
    [ -d "$ps" ] && BATTERY_PATH="$ps" && break
done

# No battery = desktop, exit silently
[ -z "$BATTERY_PATH" ] && exit 0

WARNED_20=false
WARNED_10=false
WARNED_5=false
SOUNDS_DIR="$HOME/Documents/47industries/sounds"

while true; do
    CAPACITY=$(cat "$BATTERY_PATH/capacity" 2>/dev/null)
    STATUS=$(cat "$BATTERY_PATH/status" 2>/dev/null)

    # Only warn when discharging
    if [ "$STATUS" = "Discharging" ] && [ -n "$CAPACITY" ]; then
        if [ "$CAPACITY" -le 5 ] && [ "$WARNED_5" = false ]; then
            notify-send -u critical "Critical Battery" "Battery at ${CAPACITY}% — plug in NOW" -i battery-empty-symbolic
            WARNED_5=true
        elif [ "$CAPACITY" -le 10 ] && [ "$WARNED_10" = false ]; then
            notify-send -u critical "Low Battery" "Battery at ${CAPACITY}% — find a charger" -i battery-caution-symbolic
            WARNED_10=true
        elif [ "$CAPACITY" -le 20 ] && [ "$WARNED_20" = false ]; then
            notify-send "Battery Low" "Battery at ${CAPACITY}%" -i battery-low-symbolic
            WARNED_20=true
        fi
    fi

    # Reset warnings when charging
    if [ "$STATUS" = "Charging" ] || [ "$STATUS" = "Full" ]; then
        WARNED_20=false
        WARNED_10=false
        WARNED_5=false
    fi

    sleep 60
done
