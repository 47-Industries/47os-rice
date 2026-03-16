#!/bin/bash
STATE_FILE="$HOME/.config/47industries/transparency-state"
ALACRITTY_CFG="$HOME/.config/alacritty/alacritty.toml"

# Detect desktop environment
is_hyprland() { pgrep -x Hyprland &>/dev/null; }
is_cinnamon() { pgrep -x cinnamon &>/dev/null; }

# Cinnamon-specific paths
MENU_SVG="$HOME/.themes/WhiteSur-Dark/cinnamon/assets/menu.svg"
MENU_OPAQUE="$HOME/.themes/WhiteSur-Dark/cinnamon/assets/menu-opaque.svg"
MENU_TRANS="$HOME/.themes/WhiteSur-Dark/cinnamon/assets/menu-translucent.svg"
CSS_FILE="$HOME/.themes/WhiteSur-Dark/cinnamon/cinnamon.css"
CSS_OPAQUE="$HOME/.themes/WhiteSur-Dark/cinnamon/cinnamon-opaque.css"
CSS_TRANS="$HOME/.themes/WhiteSur-Dark/cinnamon/cinnamon-translucent.css"

# Get all normal window IDs except desktop (X11 only)
get_all_wids() {
    wmctrl -l 2>/dev/null | grep -v -E "nemo-desktop|Desktop$" | awk '{print $1}'
}

if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "off" ]; then
    # ===== TURN ON TRANSPARENCY =====
    echo "on" > "$STATE_FILE"

    if is_hyprland; then
        hyprctl keyword decoration:active_opacity 0.7
        hyprctl keyword decoration:inactive_opacity 0.7
    fi

    if is_cinnamon; then
        # Apply transparency level
        [ -x "$HOME/.local/bin/47transparency" ] && "$HOME/.local/bin/47transparency" set "$("$HOME/.local/bin/47transparency" get)"

        # Enable GNOME Terminal transparency
        PROFILE=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
        [ -n "$PROFILE" ] && dconf write "/org/gnome/terminal/legacy/profiles:/:$PROFILE/use-transparent-background" true

        # Devilspie2 for new windows
        killall devilspie2 2>/dev/null; devilspie2 &>/dev/null &

        # Cinnamon panel menus (swap to translucent)
        [ -f "$MENU_TRANS" ] && cp "$MENU_TRANS" "$MENU_SVG"
        [ -f "$CSS_TRANS" ] && cp "$CSS_TRANS" "$CSS_FILE"
        dbus-send --session --dest=org.Cinnamon --type=method_call /org/Cinnamon org.Cinnamon.ReloadTheme
        # Main app menu stays solid via .appmenu-background CSS rule
        [ -x "$HOME/.local/bin/47sound-inject.sh" ] && "$HOME/.local/bin/47sound-inject.sh" &
        [ -x "$HOME/.local/bin/47glass-inject.sh" ] && "$HOME/.local/bin/47glass-inject.sh" &
    fi

    # Alacritty transparency
    if [ -f "$ALACRITTY_CFG" ]; then
        sed -i 's/^opacity = .*/opacity = 0.73/' "$ALACRITTY_CFG"
    fi

else
    # ===== TURN OFF TRANSPARENCY =====
    echo "off" > "$STATE_FILE"

    if is_hyprland; then
        hyprctl keyword decoration:active_opacity 1.0
        hyprctl keyword decoration:inactive_opacity 1.0
    fi

    # Terminals: back to solid
    if [ -f "$ALACRITTY_CFG" ]; then
        sed -i 's/^opacity = .*/opacity = 1.0/' "$ALACRITTY_CFG"
    fi

    if is_cinnamon; then
        PROFILE=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
        [ -n "$PROFILE" ] && dconf write "/org/gnome/terminal/legacy/profiles:/:$PROFILE/use-transparent-background" false

        killall devilspie2 2>/dev/null

        # Remove all window opacity
        get_all_wids | xargs -P0 -I{} xprop -id {} -f _NET_WM_WINDOW_OPACITY 32c -remove _NET_WM_WINDOW_OPACITY &

        # Cinnamon panel menus back to solid
        [ -f "$MENU_OPAQUE" ] && cp "$MENU_OPAQUE" "$MENU_SVG"
        [ -f "$CSS_OPAQUE" ] && cp "$CSS_OPAQUE" "$CSS_FILE"
        dbus-send --session --dest=org.Cinnamon --type=method_call /org/Cinnamon org.Cinnamon.ReloadTheme
        [ -x "$HOME/.local/bin/47sound-inject.sh" ] && "$HOME/.local/bin/47sound-inject.sh" &
        [ -x "$HOME/.local/bin/47glass-inject.sh" ] && "$HOME/.local/bin/47glass-inject.sh" &
    fi
fi
