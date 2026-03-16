#!/bin/bash
SFX_OPEN="$HOME/Documents/47industries/sounds/terminalenter.wav"
SFX_CLOSE="$HOME/Documents/47industries/sounds/close.mp3"
play_sound() {
    if command -v 47sound &>/dev/null; then
        47sound play "$1" &
    elif [ -f "$1" ]; then
        paplay "$1" &
    fi
}
play_sound "$SFX_OPEN"
cd "$HOME"
alacritty
play_sound "$SFX_CLOSE"
