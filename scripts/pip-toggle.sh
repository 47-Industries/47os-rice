#!/bin/bash
# 47 Industries - Picture-in-Picture toggle
# Makes current window small, always-on-top, sticky (visible on all workspaces)
# Run again to restore

WID=$(xdotool getactivewindow)
[ -z "$WID" ] && exit 0

STATE_FILE="/tmp/.pip-$WID"

if [ -f "$STATE_FILE" ]; then
    # Restore: remove always-on-top, unsticky, restore size
    wmctrl -i -r "$WID" -b remove,above,sticky
    read -r X Y W H < "$STATE_FILE"
    xdotool windowsize "$WID" "$W" "$H"
    xdotool windowmove "$WID" "$X" "$Y"
    rm -f "$STATE_FILE"
    notify-send "PiP Off" "" -i window-restore-symbolic -t 1500
else
    # Save current geometry
    eval "$(xdotool getwindowgeometry --shell "$WID")"
    echo "$X $Y $WIDTH $HEIGHT" > "$STATE_FILE"
    # Resize to small corner window
    SCREEN_W=$(xdpyinfo 2>/dev/null | awk '/dimensions:/ {print $2}' | cut -dx -f1)
    SCREEN_H=$(xdpyinfo 2>/dev/null | awk '/dimensions:/ {print $2}' | cut -dx -f2)
    PIP_W=$((SCREEN_W / 4))
    PIP_H=$((SCREEN_H / 4))
    PIP_X=$((SCREEN_W - PIP_W - 20))
    PIP_Y=$((SCREEN_H - PIP_H - 60))
    xdotool windowsize "$WID" "$PIP_W" "$PIP_H"
    xdotool windowmove "$WID" "$PIP_X" "$PIP_Y"
    wmctrl -i -r "$WID" -b add,above,sticky
    notify-send "PiP On" "Window pinned to corner" -i window-pin-symbolic -t 1500
fi
