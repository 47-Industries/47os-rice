#!/bin/bash
# Ghost Mode Toggle - VPN + MAC spoofing + DNS over TLS
GHOST_STATE_FILE="/tmp/.ghost-mode-active"
IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
ghost_on() {
    sudo ip link set "$IFACE" down 2>/dev/null
    sudo macchanger -r "$IFACE" 2>/dev/null
    sudo ip link set "$IFACE" up 2>/dev/null
    sleep 2
    sudo systemctl start stubby 2>/dev/null
    warp-cli --accept-tos connect 2>/dev/null
    touch "$GHOST_STATE_FILE"
    notify-send "Ghost Mode" "ENABLED - VPN + MAC Spoofed + Encrypted DNS" -i security-high
}
ghost_off() {
    warp-cli --accept-tos disconnect 2>/dev/null
    sudo systemctl stop stubby 2>/dev/null
    sudo ip link set "$IFACE" down 2>/dev/null
    sudo macchanger -p "$IFACE" 2>/dev/null
    sudo ip link set "$IFACE" up 2>/dev/null
    rm -f "$GHOST_STATE_FILE"
    notify-send "Ghost Mode" "DISABLED - Back to normal" -i security-low
}
case "$1" in
    on) ghost_on ;; off) ghost_off ;;
    toggle) if [ -f "$GHOST_STATE_FILE" ]; then ghost_off; else ghost_on; fi ;;
    status) if [ -f "$GHOST_STATE_FILE" ]; then echo "ON"; else echo "OFF"; fi ;;
    *) echo "Usage: ghost-mode.sh {on|off|toggle|status}" ;;
esac
