#!/bin/bash
SFX="$HOME/Documents/47industries/sounds/maximize.ogg"
if command -v 47sound &>/dev/null; then 47sound play "$SFX" &
elif [ -f "$SFX" ]; then paplay "$SFX" &; fi
wmctrl -r :ACTIVE: -b toggle,maximized_vert,maximized_horz
