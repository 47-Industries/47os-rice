#!/bin/bash

# ============================================================
#   47 OS Rice Installer
#   Applies the full 47 Industries rice to Linux Mint (Cinnamon)
#   Run: git clone <repo> && cd 47os-rice && ./install.sh
# ============================================================

# NO set -e — we handle errors individually so one failure
# doesn't leave the system half-configured

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.47os-backup/$(date +%Y%m%d-%H%M%S)"
CYAN='\033[1;36m'
WHITE='\033[1;97m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'

step=0
total=16
errors=0

progress() {
    step=$((step + 1))
    echo -e "\n${CYAN}[$step/$total]${WHITE} $1${RESET}"
}

ok() { echo -e "  ${GREEN}$1${RESET}"; }
warn() { echo -e "  ${YELLOW}WARNING: $1${RESET}"; }
fail() { echo -e "  ${RED}FAILED: $1${RESET}"; errors=$((errors + 1)); }

# Backup a file/dir before overwriting
backup() {
    local target="$1"
    if [ -e "$target" ]; then
        local rel="${target#$HOME/}"
        local dest="$BACKUP_DIR/$rel"
        mkdir -p "$(dirname "$dest")"
        cp -a "$target" "$dest" 2>/dev/null
    fi
}

# Safe gsettings — don't crash if the schema doesn't exist on this Mint version
gset() {
    gsettings set "$@" 2>/dev/null || warn "gsettings key not found: $1 $2"
}

echo -e "${CYAN}"
echo "================================================"
echo "  47 Industries Rice Installer"
echo "  For Linux Mint (Cinnamon Desktop)"
echo "================================================"
echo -e "${RESET}"

if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Don't run as root. Run as your normal user — sudo will be used when needed.${RESET}"
    exit 1
fi

if ! command -v cinnamon &>/dev/null; then
    echo -e "${RED}Cinnamon desktop not found. This script is for Linux Mint Cinnamon.${RESET}"
    exit 1
fi

echo "This will install the full 47OS rice on your system."
echo "A backup of your current configs will be saved to:"
echo "  $BACKUP_DIR"
echo ""
echo "You can undo everything later with: ./uninstall.sh"
echo ""
read -p "Continue? [y/N] " confirm
[[ "$confirm" != "y" && "$confirm" != "Y" ]] && echo "Aborted." && exit 0

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo -e "${GREEN}Backup directory created: $BACKUP_DIR${RESET}"

# ============================================================
# Save current state for uninstall
# ============================================================
echo -e "\n${CYAN}[*]${WHITE} Backing up current settings...${RESET}"

# Save current dconf state
dconf dump /org/cinnamon/ > "$BACKUP_DIR/cinnamon-dconf.dump" 2>/dev/null
dconf dump /net/launchpad/plank/ > "$BACKUP_DIR/plank-dconf.dump" 2>/dev/null

# Save current gsettings values we'll change
{
    echo "# 47OS Backup - gsettings values before install"
    for key in \
        "org.cinnamon.theme name" \
        "org.cinnamon.desktop.interface gtk-theme" \
        "org.cinnamon.desktop.interface icon-theme" \
        "org.cinnamon.desktop.interface cursor-theme" \
        "org.cinnamon.desktop.interface font-name" \
        "org.cinnamon.desktop.wm.preferences theme" \
        "org.cinnamon.desktop.wm.preferences titlebar-font" \
        "org.cinnamon.desktop.background picture-uri" \
        "org.cinnamon.desktop.background picture-options" \
        "org.cinnamon panels-enabled" \
        "org.cinnamon panels-height" \
        "org.cinnamon panel-scale-text-icons" \
        "org.cinnamon app-menu-icon-name" \
        "org.cinnamon enabled-applets" \
        "org.cinnamon enabled-extensions" \
        "org.cinnamon desktop-effects" \
        "org.cinnamon desktop-effects-close" \
        "org.cinnamon desktop-effects-map" \
        "org.cinnamon desktop-effects-minimize" \
        "org.nemo.desktop computer-icon-visible" \
        "org.nemo.desktop home-icon-visible" \
        "org.nemo.desktop network-icon-visible" \
        "org.nemo.desktop trash-icon-visible" \
        "org.nemo.desktop volumes-visible"; do
        schema=$(echo "$key" | awk '{print $1}')
        k=$(echo "$key" | awk '{print $2}')
        val=$(gsettings get $schema $k 2>/dev/null)
        [ -n "$val" ] && echo "gsettings set $schema $k $val"
    done
} > "$BACKUP_DIR/gsettings-restore.sh"
chmod +x "$BACKUP_DIR/gsettings-restore.sh"

# Backup keybindings
dconf dump /org/cinnamon/desktop/keybindings/ > "$BACKUP_DIR/keybindings-dconf.dump" 2>/dev/null

# Backup individual files we'll overwrite
backup "$HOME/.config/alacritty/alacritty.toml"
backup "$HOME/.config/gtk-3.0/gtk.css"
backup "$HOME/.xbindkeysrc"
backup "$HOME/.bashrc"
for f in "$HOME/.config/autostart/"*.desktop; do [ -f "$f" ] && backup "$f"; done

ok "Current settings backed up."

# ============================================================
# STEP 1: Install apt packages
# ============================================================
progress "Installing system packages..."
sudo apt update -qq 2>/dev/null
if sudo apt install -y \
    alacritty plank rofi xdotool wmctrl xbindkeys xss-lock \
    brightnessctl pulseaudio-utils maim nemo-preview copyq kdeconnect \
    inotify-tools devilspie2 macchanger x11-utils ffmpeg zenity \
    libinput-tools \
    python3 jq curl wget git dconf-cli lm-sensors \
    gnome-maps gnome-contacts gnome-clocks gnome-calendar cheese \
    rhythmbox shotwell drawing simple-scan 2>/dev/null; then
    ok "Done."
else
    warn "Some packages may not have installed. Non-critical — continuing."
fi

# Install Brave browser if not present
if ! command -v brave-browser &>/dev/null; then
    echo "  Installing Brave browser..."
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg 2>/dev/null
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | \
        sudo tee /etc/apt/sources.list.d/brave-browser-release.list > /dev/null 2>/dev/null
    sudo apt update -qq 2>/dev/null
    sudo apt install -y brave-browser 2>/dev/null && ok "Brave browser installed." || warn "Brave browser install failed. You can install it manually."
else
    ok "Brave browser already installed."
fi

# Replace Brave icon with Safari icon (macOS look)
if [ -f /usr/share/icons/WhiteSur-dark/apps/scalable/safari.svg ]; then
    sudo cp /usr/share/icons/WhiteSur-dark/apps/scalable/safari.svg /usr/share/icons/WhiteSur-dark/apps/scalable/brave-browser.svg
    sudo cp /usr/share/icons/WhiteSur-dark/apps/scalable/safari.svg /usr/share/icons/WhiteSur-dark/apps/scalable/com.brave.Browser.svg
    sudo gtk-update-icon-cache /usr/share/icons/WhiteSur-dark/ 2>/dev/null
    ok "Brave icon replaced with Safari icon."
fi

# Remove Firefox — Brave is the 47OS browser
if dpkg -l firefox 2>/dev/null | grep -q "^ii"; then
    echo "  Removing Firefox..."
    sudo apt remove -y firefox firefox-locale-en 2>/dev/null
    sudo apt autoremove -y 2>/dev/null
    ok "Firefox removed. Brave is the default browser."
fi

# Install Claude Code CLI
if ! command -v claude &>/dev/null; then
    echo "  Installing Claude Code..."
    if command -v npm &>/dev/null; then
        sudo npm install -g @anthropic-ai/claude-code 2>/dev/null && ok "Claude Code installed." || warn "Claude Code npm install failed."
    else
        # Install Node.js first
        curl -fsSL https://deb.nodesource.com/setup_22.x 2>/dev/null | sudo -E bash - 2>/dev/null
        sudo apt install -y nodejs 2>/dev/null
        sudo npm install -g @anthropic-ai/claude-code 2>/dev/null && ok "Claude Code installed." || warn "Claude Code install failed. Run: sudo npm install -g @anthropic-ai/claude-code"
    fi
else
    ok "Claude Code already installed."
fi

# ============================================================
# STEP 2: Install WhiteSur GTK Theme
# ============================================================
progress "Installing WhiteSur GTK theme..."
if [ -d "$HOME/.themes/WhiteSur-Dark" ]; then
    ok "WhiteSur-Dark theme already installed, skipping."
else
    # Extract pre-built theme (avoids WhiteSur installer PTY issues)
    mkdir -p "$HOME/.themes"
    tar xzf "$SCRIPT_DIR/assets/whitesur-dark-theme.tar.gz" -C "$HOME/.themes/" 2>/dev/null
    if [ -d "$HOME/.themes/WhiteSur-Dark" ]; then
        ok "WhiteSur GTK theme installed."
    else
        fail "WhiteSur theme extraction failed."
    fi
fi

# Patch the Cinnamon CSS for transparency support
if [ -d "$HOME/.themes/WhiteSur-Dark/cinnamon" ]; then
    # Install opaque + translucent CSS variants (full theme files)
    cp "$SCRIPT_DIR/assets/theme-patches/cinnamon-opaque.css" "$HOME/.themes/WhiteSur-Dark/cinnamon/" 2>/dev/null
    cp "$SCRIPT_DIR/assets/theme-patches/cinnamon-translucent.css" "$HOME/.themes/WhiteSur-Dark/cinnamon/" 2>/dev/null
    mkdir -p "$HOME/.themes/WhiteSur-Dark/cinnamon/assets"
    cp "$SCRIPT_DIR/assets/theme-patches/menu-opaque.svg" "$HOME/.themes/WhiteSur-Dark/cinnamon/assets/" 2>/dev/null
    cp "$SCRIPT_DIR/assets/theme-patches/menu-translucent.svg" "$HOME/.themes/WhiteSur-Dark/cinnamon/assets/" 2>/dev/null
    # Set initial state to opaque (solid)
    cp "$SCRIPT_DIR/assets/theme-patches/cinnamon-opaque.css" "$HOME/.themes/WhiteSur-Dark/cinnamon/cinnamon.css" 2>/dev/null
    cp "$SCRIPT_DIR/assets/theme-patches/menu-opaque.svg" "$HOME/.themes/WhiteSur-Dark/cinnamon/assets/menu.svg" 2>/dev/null
    # Initialize transparency state to off (persistent path, survives reboot)
    mkdir -p "$HOME/.config/47industries"
    echo "off" > "$HOME/.config/47industries/transparency-state"
fi

# Inject macOS rubberband selection CSS into WhiteSur GTK theme
RUBBERBAND_CSS='
/* 47OS: macOS-style rubberband selection */
.rubberband, rubberband, .view rubberband, treeview.view rubberband,
flowbox rubberband, iconview rubberband, .content-view rubberband,
GtkIconView rubberband, .nemo-desktop rubberband {
  border: 1px solid rgba(180, 180, 180, 0.6);
  background-color: rgba(160, 160, 160, 0.25);
}'
for css_file in "$HOME/.themes/WhiteSur-Dark/gtk-3.0/gtk.css" \
                "$HOME/.themes/WhiteSur-Dark/gtk-3.0/gtk-dark.css" \
                "$HOME/.themes/WhiteSur-Dark/gtk-4.0/gtk.css" \
                "$HOME/.themes/WhiteSur-Dark/gtk-4.0/gtk-Dark.css"; do
    if [ -f "$css_file" ] && ! grep -q "47OS.*rubberband" "$css_file" 2>/dev/null; then
        echo "$RUBBERBAND_CSS" >> "$css_file"
    fi
done

# ============================================================
# STEP 3: Install WhiteSur Icon Theme + Cursors
# ============================================================
progress "Installing WhiteSur icon theme + cursors..."
if [ -d "$HOME/.local/share/icons/WhiteSur-dark" ]; then
    ok "WhiteSur icons already installed, skipping."
else
    cd /tmp
    rm -rf WhiteSur-icon-theme
    if git clone --depth 1 https://github.com/vinceliuice/WhiteSur-icon-theme.git 2>/dev/null; then
        cd WhiteSur-icon-theme && ./install.sh 2>/dev/null && ok "WhiteSur icons installed." || fail "Icon theme install failed."
        cd "$SCRIPT_DIR"
    else
        fail "Could not clone WhiteSur icons. Check internet connection."
    fi
fi

if [ -d "$HOME/.local/share/icons/WhiteSur-cursors" ]; then
    ok "WhiteSur cursors already installed."
else
    cd /tmp
    rm -rf WhiteSur-cursors
    if git clone --depth 1 https://github.com/vinceliuice/WhiteSur-cursors.git 2>/dev/null; then
        cd WhiteSur-cursors && ./install.sh 2>/dev/null && ok "WhiteSur cursors installed." || fail "Cursor install failed."
        cd "$SCRIPT_DIR"
    else
        fail "Could not clone WhiteSur cursors."
    fi
fi

# Custom panel icons
mkdir -p "$HOME/.local/share/icons/custom-panel"
cp "$SCRIPT_DIR/assets/icons/"*.svg "$HOME/.local/share/icons/custom-panel/" 2>/dev/null

# Oxy-neon cursor
mkdir -p "$HOME/.icons"
cd "$HOME/.icons"
tar xzf "$SCRIPT_DIR/assets/cursors/oxy-neon-large-0.3.tar.gz" 2>/dev/null
cd "$SCRIPT_DIR"

ok "Done."

# ============================================================
# STEP 4: Install fonts
# ============================================================
progress "Installing fonts (SF Pro + Octosquares)..."
mkdir -p "$HOME/.local/share/fonts"
cp "$SCRIPT_DIR/assets/fonts/"* "$HOME/.local/share/fonts/" 2>/dev/null
fc-cache -f 2>/dev/null
ok "$(ls "$SCRIPT_DIR/assets/fonts/" 2>/dev/null | wc -l) fonts installed."

# ============================================================
# STEP 5: Install sounds
# ============================================================
progress "Installing sound effects..."
mkdir -p "$HOME/.local/share/47industries/sounds"
cp "$SCRIPT_DIR/assets/sounds/drag/"* "$HOME/.local/share/47industries/sounds/" 2>/dev/null

mkdir -p "$HOME/Documents/47industries/sounds"
cp "$SCRIPT_DIR/assets/sounds/ui/"* "$HOME/Documents/47industries/sounds/" 2>/dev/null

# Generate system sounds if not present
SOUNDS="$HOME/Documents/47industries/sounds"
if [ ! -f "$SOUNDS/startup.ogg" ] && command -v ffmpeg &>/dev/null; then
    progress "Generating system sounds..."
    # Startup chime (ascending two-tone)
    ffmpeg -y -f lavfi -i "sine=frequency=523:duration=0.3" -f lavfi -i "sine=frequency=659:duration=0.4" \
        -filter_complex "[0]afade=t=in:d=0.05,afade=t=out:st=0.2:d=0.1,volume=0.4[a];[1]adelay=200|200,afade=t=in:d=0.05,afade=t=out:st=0.25:d=0.15,volume=0.4[b];[a][b]amix=inputs=2:duration=longest,aecho=0.8:0.7:40:0.3" \
        "$SOUNDS/startup.ogg" 2>/dev/null
    # Charging boop
    ffmpeg -y -f lavfi -i "sine=frequency=880:duration=0.15" -f lavfi -i "sine=frequency=1175:duration=0.15" \
        -filter_complex "[0]afade=t=in:d=0.02,afade=t=out:st=0.1:d=0.05,volume=0.3[a];[1]adelay=100|100,afade=t=in:d=0.02,afade=t=out:st=0.1:d=0.05,volume=0.3[b];[a][b]amix=inputs=2:duration=longest" \
        "$SOUNDS/charging.ogg" 2>/dev/null
    # Lock click
    ffmpeg -y -f lavfi -i "sine=frequency=1000:duration=0.08" \
        -af "afade=t=in:d=0.01,afade=t=out:st=0.04:d=0.04,volume=0.25" \
        "$SOUNDS/lock.ogg" 2>/dev/null
    ok "System sounds generated."
fi

# Configure Cinnamon system sounds
gsettings set org.cinnamon.sounds login-enabled true
gsettings set org.cinnamon.sounds login-file "$SOUNDS/startup.ogg"
gsettings set org.cinnamon.sounds plug-enabled true
gsettings set org.cinnamon.sounds plug-file "$SOUNDS/charging.ogg"
gsettings set org.cinnamon.sounds unplug-enabled true
gsettings set org.cinnamon.sounds unplug-file "$SOUNDS/charging.ogg"
gsettings set org.cinnamon.sounds tile-enabled true
gsettings set org.cinnamon.sounds notification-enabled true
gsettings set org.cinnamon.sounds switch-enabled true
gsettings set org.cinnamon.sounds logout-enabled true

ok "Done."

# ============================================================
# STEP 6: Install scripts to ~/.local/bin
# ============================================================
progress "Installing 47 Industries scripts..."
mkdir -p "$HOME/.local/bin"

for script in 47sound 47transparency 47glass-inject.sh \
              matrix-47.py saber-drag.sh swoosh-watcher.sh 47sound-inject.sh; do
    if [ -f "$SCRIPT_DIR/scripts/$script" ]; then
        cp "$SCRIPT_DIR/scripts/$script" "$HOME/.local/bin/$script"
        chmod +x "$HOME/.local/bin/$script"
    else
        warn "Script not found: $script"
    fi
done

mkdir -p "$HOME/Documents/47industries"
for script in launch-terminal.sh toggle-transparency.sh window-close-sound.py \
              window-state-sound.py brightness-tracker.sh volume-tracker.sh \
              close-window.sh maximize-window.sh minimize-window.sh \
              fullscreen-toggle.sh lock-screen.sh powermenu.sh app-search.sh \
              spotlight-search.sh screenshot-float.sh \
              battery-monitor.sh dynamic-wallpaper.sh \
              force-quit.sh about-47os.sh pip-toggle.sh; do
    if [ -f "$SCRIPT_DIR/scripts/$script" ]; then
        cp "$SCRIPT_DIR/scripts/$script" "$HOME/Documents/47industries/$script"
        chmod +x "$HOME/Documents/47industries/$script"
    else
        warn "Script not found: $script"
    fi
done

# Copy assets to ~/Documents/47industries
cp "$SCRIPT_DIR/assets/images/panel-icon.png" "$HOME/Documents/47industries/" 2>/dev/null
cp "$SCRIPT_DIR/assets/images/launcher.png" "$HOME/Documents/47industries/" 2>/dev/null
cp "$SCRIPT_DIR/assets/images/sequoia-sunrise.jpg" "$HOME/Documents/47industries/" 2>/dev/null
cp "$SCRIPT_DIR/assets/ascii-art.txt" "$HOME/.local/share/47industries/" 2>/dev/null
cp "$SCRIPT_DIR/config/industries.rasi" "$HOME/Documents/47industries/" 2>/dev/null

# Set 47 logo as user avatar
cp "$SCRIPT_DIR/assets/images/panel-icon.png" "$HOME/.face" 2>/dev/null

# Ensure ~/.local/bin is in PATH (append only, don't duplicate)
if ! grep -q '\.local/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi

ok "Done."

# ============================================================
# STEP 7: Install Cinnamon applets
# ============================================================
progress "Installing custom Cinnamon applets..."
APPLET_DIR="$HOME/.local/share/cinnamon/applets"
mkdir -p "$APPLET_DIR"

for applet in brightness@custom fake-battery@custom \
              fake-wifi@custom 47sound@custom vpn-toggle@custom sound@cinnamon.org; do
    if [ -d "$SCRIPT_DIR/applets/$applet" ]; then
        cp -r "$SCRIPT_DIR/applets/$applet" "$APPLET_DIR/"
    else
        warn "Applet not found: $applet"
    fi
done

ok "6 custom applets installed."

# ============================================================
# STEP 8: Install Cinnamon extensions
# ============================================================
progress "Installing Cinnamon extensions..."
EXT_BASE="$HOME/.local/share/cinnamon/extensions"
mkdir -p "$EXT_BASE"

for ext in compiz-windows-effect@hermes83.github.com CinnamonBurnMyWindows@klangman CinnamonMagicLamp@klangman; do
    if [ -d "$SCRIPT_DIR/extensions/$ext" ]; then
        cp -r "$SCRIPT_DIR/extensions/$ext" "$EXT_BASE/"
        ok "Installed extension: $ext"
    else
        warn "Extension not found: $ext"
    fi
done

# ============================================================
# STEP 9: Deploy config files
# ============================================================
progress "Deploying configuration files..."

# Alacritty
mkdir -p "$HOME/.config/alacritty"
cp "$SCRIPT_DIR/config/alacritty/alacritty.toml" "$HOME/.config/alacritty/"

# Devilspie2 transparency rules (required for transparency toggle to work)
mkdir -p "$HOME/.config/devilspie2"
cp "$SCRIPT_DIR/config/devilspie2/transparency.lua" "$HOME/.config/devilspie2/"

# Spotlight search (Rofi theme)
mkdir -p "$HOME/.config/rofi/themes"
cp "$SCRIPT_DIR/config/rofi/spotlight.rasi" "$HOME/.config/rofi/themes/" 2>/dev/null

# Nemo actions (right-click extract, trash sound, etc.)
mkdir -p "$HOME/.local/share/nemo/actions"
cp "$SCRIPT_DIR/config/nemo-actions/"*.nemo_action "$HOME/.local/share/nemo/actions/" 2>/dev/null

# Touchpad gestures config (for laptops)
cp "$SCRIPT_DIR/config/libinput-gestures.conf" "$HOME/.config/" 2>/dev/null

# Smooth font rendering (macOS-quality text)
gsettings set org.cinnamon.desktop.font-rendering antialiasing 'rgba' 2>/dev/null
gsettings set org.cinnamon.desktop.font-rendering hinting 'slight' 2>/dev/null


# Auto-extract on double-click (zip, tar, etc.)
cp "$SCRIPT_DIR/config/auto-extract.desktop" "$HOME/.local/share/applications/" 2>/dev/null
xdg-mime default auto-extract.desktop application/zip 2>/dev/null

# Fastfetch
mkdir -p "$HOME/.config/fastfetch"
cp "$SCRIPT_DIR/config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/"

# Cinnamon spices configs (menu icon, calendar format, wobbly windows, etc.)
# Copy ALL spices configs from the working ISO, replacing HOMEDIR with actual home
for spice_dir in "$SCRIPT_DIR/config/cinnamon/"*/; do
    spice_name=$(basename "$spice_dir")
    mkdir -p "$HOME/.config/cinnamon/spices/$spice_name"
    for json_file in "$spice_dir"*.json; do
        [ -f "$json_file" ] || continue
        sed "s|HOMEDIR|$HOME|g" "$json_file" > "$HOME/.config/cinnamon/spices/$spice_name/$(basename "$json_file")"
    done
done

# SoundCloud web app
mkdir -p "$HOME/.local/share/applications"
cp "$SCRIPT_DIR/config/soundcloud.desktop" "$HOME/.local/share/applications/"

# Set Brave as default browser
backup "$HOME/.config/mimeapps.list"
cp "$SCRIPT_DIR/config/mimeapps.list" "$HOME/.config/"

# GTK-3.0 — append, don't replace
mkdir -p "$HOME/.config/gtk-3.0"
if [ -f "$HOME/.config/gtk-3.0/gtk.css" ]; then
    if ! grep -q "47os-rice" "$HOME/.config/gtk-3.0/gtk.css" 2>/dev/null; then
        echo "" >> "$HOME/.config/gtk-3.0/gtk.css"
        echo "/* 47os-rice start */" >> "$HOME/.config/gtk-3.0/gtk.css"
        cat "$SCRIPT_DIR/config/gtk-3.0/gtk.css" >> "$HOME/.config/gtk-3.0/gtk.css"
        echo "/* 47os-rice end */" >> "$HOME/.config/gtk-3.0/gtk.css"
    fi
else
    cp "$SCRIPT_DIR/config/gtk-3.0/gtk.css" "$HOME/.config/gtk-3.0/"
fi

# Autostart entries — only ADD ours, don't touch existing ones
mkdir -p "$HOME/.config/autostart"
for f in "$SCRIPT_DIR/config/autostart/"*.desktop; do
    [ -f "$f" ] || continue
    dest="$HOME/.config/autostart/$(basename "$f")"
    # Replace $HOME placeholder with actual home dir
    sed "s|\\\$HOME|$HOME|g" "$f" > "$dest"
done

# Xbindkeys — only install if user doesn't have one
if [ -f "$HOME/.xbindkeysrc" ]; then
    warn ".xbindkeysrc already exists. 47OS bindings saved to ~/.xbindkeysrc.47os"
    sed "s|\\\$HOME|$HOME|g" "$SCRIPT_DIR/config/xbindkeysrc" > "$HOME/.xbindkeysrc.47os"
else
    sed "s|\\\$HOME|$HOME|g" "$SCRIPT_DIR/config/xbindkeysrc" > "$HOME/.xbindkeysrc"
fi

# Plank dock launchers
mkdir -p "$HOME/.config/plank/dock1/launchers"
cp "$SCRIPT_DIR/config/plank-launchers/"*.dockitem "$HOME/.config/plank/dock1/launchers/" 2>/dev/null

# 47 Industries state files
mkdir -p "$HOME/.config/47industries"
if [ ! -f "$HOME/.config/47industries/sound-state" ]; then
    echo "muted=false" > "$HOME/.config/47industries/sound-state"
    echo "volume=100" >> "$HOME/.config/47industries/sound-state"
fi
if [ ! -f "$HOME/.config/47industries/transparency-level" ]; then
    echo "50" > "$HOME/.config/47industries/transparency-level"
fi
echo "off" > "$HOME/.config/47industries/transparency-state"

ok "Done."

# ============================================================
# STEP 10: Install system-level files (requires sudo)
# ============================================================
progress "Installing system-level assets (requires sudo)..."

# Wallpaper & branding — these just ADD files, don't overwrite system files
sudo cp "$SCRIPT_DIR/assets/images/sequoia-sunrise.jpg" /usr/share/backgrounds/ 2>/dev/null
sudo cp "$SCRIPT_DIR/assets/images/47-logo.png" /usr/share/backgrounds/ 2>/dev/null
sudo cp "$SCRIPT_DIR/assets/images/47os-logo.png" /usr/share/pixmaps/ 2>/dev/null

# 47os-logo icon in hicolor theme
for size in 16 22 24 32 48 64 128 256; do
    sudo mkdir -p "/usr/share/icons/hicolor/${size}x${size}/apps"
    sudo cp "$SCRIPT_DIR/assets/images/47os-logo.png" "/usr/share/icons/hicolor/${size}x${size}/apps/" 2>/dev/null
done
sudo gtk-update-icon-cache /usr/share/icons/hicolor/ 2>/dev/null

# Copy theme, icons, cursors, fonts SYSTEM-WIDE so login screen can see them
# (slick-greeter runs as root and can't see ~/.themes or ~/.local/share)
if [ -d "$HOME/.themes/WhiteSur-Dark" ]; then
    sudo cp -r "$HOME/.themes/WhiteSur-Dark" /usr/share/themes/ 2>/dev/null
    ok "Theme copied to /usr/share/themes/ for login screen."
fi
if [ -d "$HOME/.local/share/icons/WhiteSur-dark" ]; then
    sudo cp -r "$HOME/.local/share/icons/WhiteSur-dark" /usr/share/icons/ 2>/dev/null
    ok "Icons copied to /usr/share/icons/ for login screen."
fi
if [ -d "$HOME/.local/share/icons/WhiteSur-cursors" ]; then
    sudo cp -r "$HOME/.local/share/icons/WhiteSur-cursors" /usr/share/icons/ 2>/dev/null
    ok "Cursors copied to /usr/share/icons/ for login screen."
fi
# Fonts system-wide for login screen
sudo mkdir -p /usr/local/share/fonts/47os
sudo cp "$SCRIPT_DIR/assets/fonts/"* /usr/local/share/fonts/47os/ 2>/dev/null
sudo fc-cache -f 2>/dev/null

# Login screen — BACKUP first
if [ -f /etc/lightdm/slick-greeter.conf ]; then
    sudo cp /etc/lightdm/slick-greeter.conf "$BACKUP_DIR/slick-greeter.conf.bak"
    ok "Login screen config backed up."
fi
sudo cp "$SCRIPT_DIR/system/lightdm/slick-greeter.conf" /etc/lightdm/slick-greeter.conf 2>/dev/null

# Cursor on login screen
sudo mkdir -p /etc/lightdm/lightdm.conf.d
sudo cp "$SCRIPT_DIR/system/lightdm/51-cursor.conf" /etc/lightdm/lightdm.conf.d/ 2>/dev/null

# Custom macOS-style login screen (web-greeter + 47-macos theme)
if [ -d "$SCRIPT_DIR/system/web-greeter/themes/47-macos" ]; then
    # Install web-greeter if not already installed
    if ! command -v web-greeter &>/dev/null; then
        progress "Installing web-greeter for custom login screen..."
        # Try apt first (some distros package it)
        sudo apt-get install -y web-greeter 2>/dev/null || \
        sudo apt-get install -y nody-greeter 2>/dev/null || \
        warn "web-greeter not available via apt — install manually from https://github.com/JezerM/web-greeter"
    fi

    if command -v web-greeter &>/dev/null; then
        # Install the 47-macos theme
        sudo mkdir -p /usr/share/web-greeter/themes
        sudo cp -r "$SCRIPT_DIR/system/web-greeter/themes/47-macos" /usr/share/web-greeter/themes/
        ok "47-macos login theme installed."

        # Install web-greeter config
        if [ -f /etc/lightdm/web-greeter.yml ]; then
            sudo cp /etc/lightdm/web-greeter.yml "$BACKUP_DIR/web-greeter.yml.bak"
        fi
        sudo cp "$SCRIPT_DIR/system/lightdm/web-greeter.yml" /etc/lightdm/web-greeter.yml 2>/dev/null

        # Set web-greeter as the active greeter
        if [ -f /etc/lightdm/lightdm.conf.d/50-greeter.conf ]; then
            sudo cp /etc/lightdm/lightdm.conf.d/50-greeter.conf "$BACKUP_DIR/50-greeter.conf.bak"
        fi
        sudo cp "$SCRIPT_DIR/system/lightdm/50-greeter.conf" /etc/lightdm/lightdm.conf.d/ 2>/dev/null
        ok "Custom macOS login screen configured."
    fi
fi

# Plymouth boot splash (47 logo on boot)
if [ -d "$SCRIPT_DIR/system/plymouth/47-logo" ]; then
    sudo cp -r "$SCRIPT_DIR/system/plymouth/47-logo" /usr/share/plymouth/themes/
    sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
        /usr/share/plymouth/themes/47-logo/47-logo.plymouth 200 2>/dev/null
    sudo update-alternatives --set default.plymouth \
        /usr/share/plymouth/themes/47-logo/47-logo.plymouth 2>/dev/null
    sudo update-initramfs -u 2>/dev/null
    ok "Plymouth boot splash installed (47 logo)."
fi

# GRUB — instant boot, 47 OS branding
sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub 2>/dev/null
sudo sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub 2>/dev/null
if ! grep -q "GRUB_TIMEOUT_STYLE" /etc/default/grub 2>/dev/null; then
    echo 'GRUB_TIMEOUT_STYLE=hidden' | sudo tee -a /etc/default/grub > /dev/null
fi
sudo sed -i "s/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR=\"47 OS\"/" /etc/default/grub 2>/dev/null
sudo update-grub 2>/dev/null
ok "GRUB configured (instant boot, 47 OS branding)."

# dconf system defaults + profile (CRITICAL - without the profile, system DB is ignored)
sudo mkdir -p /etc/dconf/db/local.d /etc/dconf/profile
echo -e "user-db:user\nsystem-db:local" | sudo tee /etc/dconf/profile/user > /dev/null
sudo cp "$SCRIPT_DIR/system/dconf/00-47os-defaults" /etc/dconf/db/local.d/ 2>/dev/null
sudo dconf update 2>/dev/null
ok "dconf profile + system database configured."

# GSchema override — BACKUP first
if [ -f /usr/share/glib-2.0/schemas/zz_47os.gschema.override ]; then
    sudo cp /usr/share/glib-2.0/schemas/zz_47os.gschema.override "$BACKUP_DIR/" 2>/dev/null
fi
sudo cp "$SCRIPT_DIR/system/schemas/zz_47os.gschema.override" /usr/share/glib-2.0/schemas/ 2>/dev/null
sudo glib-compile-schemas /usr/share/glib-2.0/schemas/ 2>/dev/null

# Theme enforcement script
sudo cp "$SCRIPT_DIR/system/47os-force-theme.sh" /usr/local/bin/ 2>/dev/null
sudo chmod +x /usr/local/bin/47os-force-theme.sh 2>/dev/null

sudo mkdir -p /etc/xdg/autostart
sudo tee /etc/xdg/autostart/47os-force-theme.desktop > /dev/null 2>/dev/null <<'THEMEDESKTOP'
[Desktop Entry]
Type=Application
Name=47OS Theme Enforcement
Exec=/usr/local/bin/47os-force-theme.sh
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
THEMEDESKTOP

ok "Done."

# ============================================================
# STEP 11: Write first-login apply script
# ============================================================
# CRITICAL: Don't modify dconf/gsettings live — it crashes Cinnamon.
# Instead, write a one-shot script that runs on NEXT login.
# This is the same approach that worked for the 47OS ISO installer.
progress "Creating first-login apply script..."

cat > "$HOME/.config/autostart/47os-first-login.desktop" <<'FIRSTLOGIN'
[Desktop Entry]
Type=Application
Name=47OS First Login Setup
Exec=/bin/bash -c "$HOME/.config/47industries/apply-rice.sh"
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=3
FIRSTLOGIN

cat > "$HOME/.config/47industries/apply-rice.sh" <<'APPLYSCRIPT'
#!/bin/bash
# 47OS Rice - First Login Script
# The heavy lifting is done by the system dconf database + gschema override.
# This script handles: user-specific paths, menu icon patch, transparency init.

sleep 5  # Wait for Cinnamon to fully load

INSTALL_DIR=$(cat "$HOME/.config/47industries/install-path" 2>/dev/null)
[ -z "$INSTALL_DIR" ] && INSTALL_DIR="$HOME/47os-rice"

# Load user-specific settings (keybindings with $HOME paths, plank, etc.)
INI="$INSTALL_DIR/config/dconf/user-settings.ini"
if [ -f "$INI" ]; then
    sed "s|HOMEDIR|$HOME|g" "$INI" | dconf load /
fi

# Patch menu icon in Cinnamon's generated config (it overwrites our 0.json on first load)
MENU_CFG="$HOME/.config/cinnamon/spices/menu@cinnamon.org/0.json"
if [ -f "$MENU_CFG" ] && command -v python3 &>/dev/null; then
    python3 -c "
import json
with open('$MENU_CFG') as f:
    d = json.load(f)
d['menu-custom']['value'] = True
d['menu-icon']['value'] = '$HOME/Documents/47industries/panel-icon.png'
d['menu-icon-size']['value'] = 32
with open('$MENU_CFG', 'w') as f:
    json.dump(d, f, indent=4)
" 2>/dev/null
fi

# Init transparency state
echo "off" > "$HOME/.config/47industries/transparency-state"

# Reload Cinnamon to pick up the menu icon change
sleep 1
DISPLAY=:0 dbus-send --session --dest=org.Cinnamon --type=method_call \
    /org/Cinnamon org.Cinnamon.Eval string:"global.reexec_self();" 2>/dev/null

# Self-destruct
rm -f "$HOME/.config/autostart/47os-first-login.desktop"
APPLYSCRIPT

chmod +x "$HOME/.config/47industries/apply-rice.sh"

ok "First-login apply script created. All settings will apply on next login."
ok "This prevents Cinnamon from crashing during the install."

# ============================================================
# STEP 15: Add splash screen to .bashrc
# ============================================================
progress "Setting up terminal splash screen..."

# Red prompt color
if ! grep -q '01;31m' "$HOME/.bashrc" 2>/dev/null; then
    sed -i 's/\\033\[01;32m/\\033[01;31m/g' "$HOME/.bashrc" 2>/dev/null
    ok "Bash prompt set to red."
fi

# Add ~/bin to PATH
if ! grep -q 'HOME/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo '' >> "$HOME/.bashrc"
    echo '# Add ~/bin to PATH for custom scripts' >> "$HOME/.bashrc"
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
fi
mkdir -p "$HOME/bin"

# Matrix splash screen
if ! grep -q "matrix-47.py" "$HOME/.bashrc" 2>/dev/null; then
    echo '' >> "$HOME/.bashrc"
    echo '# 47 Industries Terminal Splash' >> "$HOME/.bashrc"
    echo 'if [ -f "$HOME/.local/bin/matrix-47.py" ]; then python3 "$HOME/.local/bin/matrix-47.py"; fi' >> "$HOME/.bashrc"
    ok "Added matrix splash to .bashrc (with safety check)."
else
    ok "Splash screen already in .bashrc."
fi

# ============================================================
# STEP 16: Copy browser extension
# ============================================================
progress "Copying browser extension..."
mkdir -p "$HOME/Documents/47industries/47-glass-extension"
cp -r "$SCRIPT_DIR/browser-extension/"* "$HOME/Documents/47industries/47-glass-extension/" 2>/dev/null
ok "Done."

# ============================================================
# Save install manifest for uninstall
# ============================================================
echo "$BACKUP_DIR" > "$HOME/.config/47industries/backup-path"
echo "$SCRIPT_DIR" > "$HOME/.config/47industries/install-path"

# ============================================================
# DONE
# ============================================================
echo ""
echo -e "${CYAN}================================================${RESET}"
if [ "$errors" -eq 0 ]; then
    echo -e "${GREEN}  47 Industries rice installed successfully!${RESET}"
else
    echo -e "${YELLOW}  47 Industries rice installed with $errors warning(s).${RESET}"
fi
echo -e "${CYAN}================================================${RESET}"
echo ""
echo -e "${WHITE}  Backup saved to:${RESET} $BACKUP_DIR"
echo -e "${WHITE}  To undo:${RESET} ./uninstall.sh"
echo ""
echo -e "${WHITE}  What was installed:${RESET}"
echo "  - WhiteSur Dark theme + icons + cursors"
echo "  - SF Pro Display fonts"
echo "  - Alacritty terminal (neon cyan theme)"
echo "  - Plank dock (macOS-style, bottom, zoom 175%)"
echo "  - 4 custom panel applets (added to your existing panel)"
echo "  - Wobbly windows effect"
echo "  - 47 Sound system (sounds on all actions)"
echo "  - Transparency toggle (Ctrl+Shift+T)"
echo "  - Ghost Mode (VPN + MAC spoof + encrypted DNS)"
echo "  - Matrix terminal splash screen"
echo "  - 12 keybindings (added alongside your existing ones)"
echo "  - Custom login screen"
echo ""
echo -e "${WHITE}  To finish:${RESET}"
echo "  1. Log out and log back in (or Ctrl+Alt+Esc to restart Cinnamon)"
echo "  2. Browser extension: load ~/Documents/47industries/47-glass-extension/"
echo "     as unpacked extension in Brave/Chrome"
echo ""
echo -e "${WHITE}  Key shortcuts:${RESET}"
echo "  Ctrl+Alt+T     - Open terminal (with sound)"
echo "  Ctrl+Shift+T   - Toggle transparency"
echo "  Ctrl+Q         - Close window (with sound)"
echo "  Ctrl+Shift+F   - Fullscreen"
echo "  Ctrl+Shift+L   - Lock screen"
echo "  F2/F3          - Brightness down/up"
echo "  F8/F9/F10      - Mute/Vol down/Vol up"
echo ""
echo -e "${CYAN}  47 Industries${RESET}"
echo ""
