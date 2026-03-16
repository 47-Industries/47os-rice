#!/bin/bash
SFX="$HOME/Documents/47industries/sounds/togglelock.mp3"
if command -v 47sound &>/dev/null; then 47sound play "$SFX" &
elif [ -f "$SFX" ]; then paplay "$SFX" &; fi
if pgrep -x Hyprland &>/dev/null; then hyprlock; else dm-tool lock; fi
