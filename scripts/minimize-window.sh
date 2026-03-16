#!/bin/bash
SFX="$HOME/Documents/47industries/sounds/minimize.ogg"
if command -v 47sound &>/dev/null; then 47sound play "$SFX" &
elif [ -f "$SFX" ]; then paplay "$SFX" &; fi
xdotool getactivewindow windowminimize
