#!/bin/bash
# 47 Industries - Battery Monitor + Power-Aware Effects
# Runs in background, checks battery every 60 seconds.
# Only active on laptops (exits immediately on desktops).
#
# Two jobs:
#   1. Low-battery notifications (original behavior).
#   2. Actually save power: on battery, disable the GPU-heavy compositing
#      effects (wobbly windows, BurnMyWindows, MagicLamp) this rice enables
#      by default. Re-enable automatically the moment AC is plugged back in.
#      A rice that turns on shader-driven window effects and never turns
#      them off on battery is actively working against battery life.

BATTERY_PATH=""
for ps in /sys/class/power_supply/BAT*; do
    [ -d "$ps" ] && BATTERY_PATH="$ps" && break
done

# No battery = desktop, exit silently
[ -z "$BATTERY_PATH" ] && exit 0

WARNED_20=false
WARNED_10=false
WARNED_5=false
EFFECTS_STATE="on"   # tracks whether we've already toggled effects off

disable_gpu_effects() {
    [ "$EFFECTS_STATE" = "off" ] && return
    gsettings set org.cinnamon desktop-effects false 2>/dev/null
    gsettings set org.cinnamon desktop-effects-close false 2>/dev/null
    gsettings set org.cinnamon desktop-effects-map false 2>/dev/null
    gsettings set org.cinnamon desktop-effects-minimize false 2>/dev/null
    EFFECTS_STATE="off"
}

restore_gpu_effects() {
    [ "$EFFECTS_STATE" = "on" ] && return
    gsettings set org.cinnamon desktop-effects true 2>/dev/null
    gsettings set org.cinnamon desktop-effects-close true 2>/dev/null
    gsettings set org.cinnamon desktop-effects-map true 2>/dev/null
    gsettings set org.cinnamon desktop-effects-minimize true 2>/dev/null
    EFFECTS_STATE="on"
}

while true; do
    CAPACITY=$(cat "$BATTERY_PATH/capacity" 2>/dev/null)
    STATUS=$(cat "$BATTERY_PATH/status" 2>/dev/null)

    if [ "$STATUS" = "Discharging" ]; then
        disable_gpu_effects

        if [ -n "$CAPACITY" ]; then
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
    fi

    # Reset warnings + restore effects when charging
    if [ "$STATUS" = "Charging" ] || [ "$STATUS" = "Full" ]; then
        WARNED_20=false
        WARNED_10=false
        WARNED_5=false
        restore_gpu_effects
    fi

    sleep 60
done
