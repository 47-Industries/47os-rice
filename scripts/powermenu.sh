#!/usr/bin/env bash
choice=$(printf "Shutdown\nReboot\nLock\nLogout\nCancel" | rofi -dmenu -theme ~/Documents/47industries/industries.rasi -p "What option?")
case "$choice" in
    Shutdown) systemctl poweroff ;;
    Reboot) systemctl reboot ;;
    Lock) if pgrep -x Hyprland &>/dev/null; then hyprlock; else dm-tool lock; fi ;;
    Logout)
        if pgrep -x Hyprland &>/dev/null; then hyprctl dispatch exit
        elif pgrep -x cinnamon &>/dev/null; then cinnamon-session-quit --logout --force
        else loginctl terminate-user "$USER"; fi ;;
    *) exit 0 ;;
esac
