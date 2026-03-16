#!/bin/bash
SFX="$HOME/Documents/47industries/sounds/close.mp3"
if command -v 47sound &>/dev/null; then 47sound play "$SFX" &
elif [ -f "$SFX" ]; then paplay "$SFX" &; fi
xdotool getactivewindow windowclose
