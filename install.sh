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
# Fix any broken package state before installing (prevents failures from prior dpkg errors)
sudo dpkg --configure -a 2>/dev/null
sudo apt --fix-broken install -y 2>/dev/null
sudo apt update -qq 2>/dev/null
if sudo apt install -y \
    alacritty plank rofi xdotool wmctrl xbindkeys xss-lock \
    brightnessctl pulseaudio-utils maim nemo-preview copyq kdeconnect \
    inotify-tools devilspie2 macchanger x11-utils ffmpeg zenity \
    libinput-tools \
    bluez bluez-tools blueman v4l-utils \
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
# STEP 1b: Battery/power management (laptops)
# ============================================================
progress "Setting up power management (TLP)..."

# TLP is the actual battery-life fix. The rice previously shipped zero
# power-management tooling while adding always-on GPU compositing effects
# (wobbly windows, BurnMyWindows, MagicLamp) and a devilspie2 transparency
# daemon — net effect was worse battery life, not better.
if sudo apt install -y tlp tlp-rdw powertop 2>/dev/null; then
    ok "TLP + powertop installed."
else
    warn "TLP install failed — battery tuning skipped."
fi

# power-profiles-daemon fights with TLP over the same knobs if both run.
if systemctl is-active --quiet power-profiles-daemon 2>/dev/null; then
    sudo systemctl disable --now power-profiles-daemon 2>/dev/null
    warn "Disabled power-profiles-daemon (conflicts with TLP)."
fi

sudo systemctl enable --now tlp.service 2>/dev/null && ok "TLP enabled." || warn "Could not enable TLP."

# DO NOT blanket-run `powertop --auto-tune` at boot. It switches on USB
# autosuspend for EVERY device indiscriminately, which is the classic cause of
# "my wireless mouse randomly stops responding", dead USB keyboards, and
# webcams that won't wake. Measured on a real 47 OS box: USB Optical Mouse,
# Gaming Keyboard and an HD Pro Webcam C920 all sit on USB and would all be
# suspended by it. TLP already delivers the actual battery wins (CPU
# energy-perf policy, SATA ALPM, PCIe ASPM, wifi power save, runtime PM)
# without that footgun, so we let TLP own power management and keep powertop
# installed purely as a diagnostic (`sudo powertop`).
sudo mkdir -p /etc/tlp.d
sudo tee /etc/tlp.d/47os-power.conf > /dev/null 2>&1 <<'TLPCONF'
# 47 OS power tuning. Safe defaults: real battery savings, no input-device
# suspends. Written by 47os-rice install.sh.

# Keep USB autosuspend OFF. This is the setting that breaks mice, keyboards,
# webcams and dongles. The battery it saves is negligible next to the CPU and
# PCIe knobs below.
USB_AUTOSUSPEND=0

# The knobs that actually matter on battery.
CPU_ENERGY_PERF_POLICY_ON_BAT=power
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_BOOST_ON_BAT=0
PLATFORM_PROFILE_ON_BAT=low-power
SATA_LINKPWR_ON_BAT=med_power_with_dipm
PCIE_ASPM_ON_BAT=powersupersave
WIFI_PWR_ON_BAT=on
RUNTIME_PM_ON_BAT=auto
DISK_APM_LEVEL_ON_BAT="128 128"

# On AC, don't handicap the machine.
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_BOOST_ON_AC=1
WIFI_PWR_ON_AC=off
TLPCONF
sudo systemctl restart tlp.service 2>/dev/null
ok "TLP tuned (USB autosuspend deliberately OFF - keeps mice/keyboards/webcams alive)."

ok "Done."

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
    else
        fail "Could not clone WhiteSur icons. Check internet connection."
    fi
    cd "$SCRIPT_DIR"
fi

if [ -d "$HOME/.local/share/icons/WhiteSur-cursors" ]; then
    ok "WhiteSur cursors already installed."
else
    cd /tmp
    rm -rf WhiteSur-cursors
    if git clone --depth 1 https://github.com/vinceliuice/WhiteSur-cursors.git 2>/dev/null; then
        cd WhiteSur-cursors && ./install.sh 2>/dev/null && ok "WhiteSur cursors installed." || fail "Cursor install failed."
    else
        fail "Could not clone WhiteSur cursors."
    fi
    cd "$SCRIPT_DIR"
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

# System sounds
SOUNDS="$HOME/Documents/47industries/sounds"

# Startup: the arc reactor spin-up. Shipped as a real audio file, not a
# generated sine chime, and it also replaces the greeter's login sound so the
# boot and the login screen say the same thing.
if [ -f "$SCRIPT_DIR/assets/sounds/system/arc-reactor.ogg" ]; then
    cp -f "$SCRIPT_DIR/assets/sounds/system/arc-reactor.ogg" "$SOUNDS/startup.ogg"
    ok "Arc reactor startup sound installed."
fi

if [ ! -f "$SOUNDS/charging.ogg" ] && command -v ffmpeg &>/dev/null; then
    progress "Generating system sounds..."
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
gset org.cinnamon.sounds login-enabled true
gset org.cinnamon.sounds login-file "$SOUNDS/startup.ogg"
gset org.cinnamon.sounds plug-enabled true
gset org.cinnamon.sounds plug-file "$SOUNDS/charging.ogg"
gset org.cinnamon.sounds unplug-enabled true
gset org.cinnamon.sounds unplug-file "$SOUNDS/charging.ogg"
gset org.cinnamon.sounds tile-enabled true
gset org.cinnamon.sounds notification-enabled true
gset org.cinnamon.sounds switch-enabled true
gset org.cinnamon.sounds logout-enabled true

ok "Done."

# ============================================================
# STEP 6: Install scripts to ~/.local/bin
# ============================================================
progress "Installing 47 Industries scripts..."
mkdir -p "$HOME/.local/bin"

for script in 47sound 47transparency 47glass-inject.sh \
              matrix-47.py saber-drag.sh swoosh-watcher.sh 47sound-inject.sh \
              middle-click-hold.py; do
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

# Set 47 logo as user avatar (black bg, white logo — looks clean on login screen)
cp "$SCRIPT_DIR/system/web-greeter/themes/47-macos/avatar.png" "$HOME/.face" 2>/dev/null
sudo cp "$SCRIPT_DIR/system/web-greeter/themes/47-macos/avatar.png" "/var/lib/AccountsService/icons/$USER" 2>/dev/null
# Tell AccountsService to use the icon (required for slick-greeter and lightdm)
sudo mkdir -p /var/lib/AccountsService/users
ACCT_FILE="/var/lib/AccountsService/users/$USER"
if [ -f "$ACCT_FILE" ]; then
    # Update existing Icon line or add it
    if grep -q '^Icon=' "$ACCT_FILE"; then
        sudo sed -i "s|^Icon=.*|Icon=/var/lib/AccountsService/icons/$USER|" "$ACCT_FILE"
    else
        echo "Icon=/var/lib/AccountsService/icons/$USER" | sudo tee -a "$ACCT_FILE" >/dev/null
    fi
else
    sudo tee "$ACCT_FILE" >/dev/null <<AVATAR
[User]
Icon=/var/lib/AccountsService/icons/$USER
AVATAR
fi

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
              fake-wifi@custom bluetooth@custom 47sound@custom vpn-toggle@custom sound@cinnamon.org; do
    if [ -d "$SCRIPT_DIR/applets/$applet" ]; then
        cp -r "$SCRIPT_DIR/applets/$applet" "$APPLET_DIR/"
    else
        warn "Applet not found: $applet"
    fi
done

ok "7 custom applets installed."

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
gset org.cinnamon.desktop.font-rendering antialiasing 'rgba'
gset org.cinnamon.desktop.font-rendering hinting 'slight'


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

# Replace Brave icon with Safari icon (macOS look) — must run after icons are copied system-wide
if [ -f /usr/share/icons/WhiteSur-dark/apps/scalable/safari.svg ]; then
    sudo cp /usr/share/icons/WhiteSur-dark/apps/scalable/safari.svg /usr/share/icons/WhiteSur-dark/apps/scalable/brave-browser.svg
    sudo cp /usr/share/icons/WhiteSur-dark/apps/scalable/safari.svg /usr/share/icons/WhiteSur-dark/apps/scalable/com.brave.Browser.svg
    sudo gtk-update-icon-cache /usr/share/icons/WhiteSur-dark/ 2>/dev/null
    ok "Brave icon replaced with Safari icon."
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
    if ! command -v web-greeter &>/dev/null && ! command -v nody-greeter &>/dev/null; then
        progress "Installing web-greeter for custom login screen..."
        # Try apt first (some distros package it)
        if ! sudo apt-get install -y web-greeter 2>/dev/null && \
           ! sudo apt-get install -y nody-greeter 2>/dev/null; then
            # Download web-greeter .deb from GitHub releases
            progress "Downloading web-greeter from GitHub..."
            WG_DEB="/tmp/web-greeter.deb"
            # Releases use -ubuntu.deb / -debian.deb naming (not arch-based)
            WG_DISTRO="ubuntu"
            # Try nody-greeter first (actively maintained fork)
            if curl -fsSL -o "$WG_DEB" "https://github.com/JezerM/nody-greeter/releases/download/1.6.2/nody-greeter-1.6.2-${WG_DISTRO}.deb" 2>/dev/null || \
               wget -q -O "$WG_DEB" "https://github.com/JezerM/nody-greeter/releases/download/1.6.2/nody-greeter-1.6.2-${WG_DISTRO}.deb" 2>/dev/null; then
                sudo dpkg -i "$WG_DEB" 2>/dev/null
                sudo apt-get install -f -y 2>/dev/null  # fix any missing deps
                rm -f "$WG_DEB"
            # Fallback: try web-greeter .deb
            elif curl -fsSL -o "$WG_DEB" "https://github.com/JezerM/web-greeter/releases/download/3.5.3/web-greeter-3.5.3-${WG_DISTRO}.deb" 2>/dev/null || \
                 wget -q -O "$WG_DEB" "https://github.com/JezerM/web-greeter/releases/download/3.5.3/web-greeter-3.5.3-${WG_DISTRO}.deb" 2>/dev/null; then
                sudo dpkg -i "$WG_DEB" 2>/dev/null
                sudo apt-get install -f -y 2>/dev/null
                rm -f "$WG_DEB"
            else
                warn "Could not download web-greeter — login screen will use slick-greeter fallback."
                warn "To install manually: https://github.com/JezerM/nody-greeter/releases"
            fi
        fi
    fi

    # --- FAILSAFE: arm the revert BEFORE swapping the greeter ---
    # If the custom greeter ever fails to start, systemd restores the stock
    # greeter automatically. Without this, a bad greeter = black screen,
    # no login, on a machine you may have no other way into.
    if [ -f "$SCRIPT_DIR/system/failsafe/47os-greeter-revert.sh" ]; then
        sudo install -m 0755 "$SCRIPT_DIR/system/failsafe/47os-greeter-revert.sh" /usr/local/bin/47os-greeter-revert.sh
        sudo install -m 0644 "$SCRIPT_DIR/system/failsafe/47os-greeter-revert.service" /etc/systemd/system/47os-greeter-revert.service
        sudo mkdir -p /etc/systemd/system/lightdm.service.d
        sudo install -m 0644 "$SCRIPT_DIR/system/failsafe/47os-failsafe.conf" /etc/systemd/system/lightdm.service.d/47os-failsafe.conf
        sudo systemctl daemon-reload 2>/dev/null
        ok "Login-screen failsafe armed (auto-reverts if the custom greeter fails)."
    else
        warn "Failsafe files missing — skipping custom greeter to avoid a no-login boot."
        GREETER_BIN=""
        SKIP_GREETER=1
    fi

    # Determine which greeter binary is available
    GREETER_BIN=""
    if command -v web-greeter &>/dev/null; then
        GREETER_BIN="web-greeter"
    elif command -v nody-greeter &>/dev/null; then
        GREETER_BIN="nody-greeter"
    fi

    if [ -n "$GREETER_BIN" ] && [ -z "${SKIP_GREETER:-}" ]; then
        # Install the 47-macos theme (check both possible theme dirs)
        THEME_DIR="/usr/share/web-greeter/themes"
        [ "$GREETER_BIN" = "nody-greeter" ] && [ -d "/usr/share/nody-greeter/themes" ] && THEME_DIR="/usr/share/nody-greeter/themes"
        sudo mkdir -p "$THEME_DIR"
        sudo cp -r "$SCRIPT_DIR/system/web-greeter/themes/47-macos" "$THEME_DIR/"
        ok "47-macos login theme installed."

        # Install web-greeter config
        if [ -f /etc/lightdm/web-greeter.yml ]; then
            sudo cp /etc/lightdm/web-greeter.yml "$BACKUP_DIR/web-greeter.yml.bak"
        fi
        sudo cp "$SCRIPT_DIR/system/lightdm/web-greeter.yml" /etc/lightdm/web-greeter.yml 2>/dev/null

        # Set greeter as the active greeter
        if [ -f /etc/lightdm/lightdm.conf.d/50-greeter.conf ]; then
            sudo cp /etc/lightdm/lightdm.conf.d/50-greeter.conf "$BACKUP_DIR/50-greeter.conf.bak"
        fi
        # Write the correct greeter name into the conf
        echo -e "[Seat:*]\ngreeter-session=${GREETER_BIN}\nuser-session=cinnamon" | sudo tee /etc/lightdm/lightdm.conf.d/50-greeter.conf >/dev/null

        # Also update the main lightdm.conf (conf.d alone won't override it)
        if [ -f /etc/lightdm/lightdm.conf ]; then
            sudo cp /etc/lightdm/lightdm.conf "$BACKUP_DIR/lightdm.conf.bak"
            sudo sed -i "s/^greeter-session=.*/greeter-session=${GREETER_BIN}/" /etc/lightdm/lightdm.conf
            # If greeter-session line doesn't exist, add it under [Seat:*]
            if ! grep -q '^greeter-session=' /etc/lightdm/lightdm.conf; then
                sudo sed -i "/^\[Seat:\*\]/a greeter-session=${GREETER_BIN}" /etc/lightdm/lightdm.conf
            fi
        fi
        ok "Custom macOS login screen configured (${GREETER_BIN})."
    else
        warn "web-greeter/nody-greeter not available — using slick-greeter with macOS styling."
    fi
fi

# Plymouth boot splash (47 logo on boot)
if [ -d "$SCRIPT_DIR/system/plymouth/47-logo" ]; then
    sudo cp -r "$SCRIPT_DIR/system/plymouth/47-logo" /usr/share/plymouth/themes/
    sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
        /usr/share/plymouth/themes/47-logo/47-logo.plymouth 300 2>/dev/null
    sudo update-alternatives --set default.plymouth \
        /usr/share/plymouth/themes/47-logo/47-logo.plymouth 2>/dev/null

    # Back up current initramfs before rebuilding (prevents kernel panic if DKMS modules are broken)
    CURRENT_KERNEL=$(uname -r)
    INITRAMFS="/boot/initrd.img-${CURRENT_KERNEL}"
    if [ -f "$INITRAMFS" ]; then
        sudo cp "$INITRAMFS" "${INITRAMFS}.47backup"
    fi

    # Remove broken DKMS modules that can corrupt initramfs (common on MacBooks)
    if dkms status 2>/dev/null | grep -qi "bad\|error\|broken"; then
        warn "Found broken DKMS modules — cleaning up before initramfs rebuild..."
        for mod in $(dkms status 2>/dev/null | grep -i "bad\|error\|broken" | cut -d',' -f1); do
            sudo dkms remove "$mod" --all 2>/dev/null
        done
    fi
    # Specifically handle broadcom-sta which frequently fails on MacBooks
    if dkms status broadcom-sta 2>/dev/null | grep -qi "error\|bad"; then
        sudo dkms remove broadcom-sta/6.30.223.271 --all 2>/dev/null
    fi

    if sudo update-initramfs -u; then
        ok "Plymouth boot splash installed (47 logo)."
        # Clean up backup since rebuild succeeded
        sudo rm -f "${INITRAMFS}.47backup"
    else
        warn "Initramfs rebuild failed — restoring backup to prevent boot issues."
        if [ -f "${INITRAMFS}.47backup" ]; then
            sudo mv "${INITRAMFS}.47backup" "$INITRAMFS"
        fi
        warn "Plymouth theme installed but boot splash may not appear until next kernel update."
    fi
fi

# GRUB — instant boot, 47 OS branding (backup first for uninstall)
sudo cp /etc/default/grub "$BACKUP_DIR/grub.default.bak" 2>/dev/null
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

# Resolve from the checkout we are ACTUALLY running from. install-path is
# written at the very END of this script, so on a first install it is empty
# here and the old fallback ($HOME/47os-rice) silently missed the INI for
# anyone who cloned anywhere else — which meant panels-enabled and the applet
# layout never got applied at all. 2026-09-05.
INSTALL_DIR="__47OS_SCRIPT_DIR__"
[ -f "$INSTALL_DIR/config/dconf/user-settings.ini" ] || INSTALL_DIR=$(cat "$HOME/.config/47industries/install-path" 2>/dev/null)
[ -n "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/config/dconf/user-settings.ini" ] || INSTALL_DIR="$HOME/47os-rice"

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

# Restart Plank so it picks up the new dconf settings and launchers
killall plank 2>/dev/null
sleep 1
nohup plank &>/dev/null &

# Reload Cinnamon to pick up the menu icon change
sleep 1
DISPLAY=:0 dbus-send --session --dest=org.Cinnamon --type=method_call \
    /org/Cinnamon org.Cinnamon.Eval string:"global.reexec_self();" 2>/dev/null

# Self-destruct
rm -f "$HOME/.config/autostart/47os-first-login.desktop"
APPLYSCRIPT

# The heredoc above is quoted, so $SCRIPT_DIR could not expand inside it and
# would have been UNSET at login. Bake the real checkout path in now.
sed -i "s|__47OS_SCRIPT_DIR__|$SCRIPT_DIR|" "$HOME/.config/47industries/apply-rice.sh"
chmod +x "$HOME/.config/47industries/apply-rice.sh"

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

# Terminal title lock — lets user run "title My Session" to pin the tab name
# The prompt resets the title after every command so subprocesses can't override it
if ! grep -q "TERM_TITLE" "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" << 'TITLEBLOCK'

# 47 Industries — Persistent terminal title
# Usage: title "My Session Name" (locks the tab title)
title() { export TERM_TITLE="$*"; }
if [ -n "$TERM_TITLE" ]; then
    PROMPT_COMMAND='echo -ne "\033]0;${TERM_TITLE}\007"'
fi
TITLEBLOCK
    ok "Added 'title' command to .bashrc (pin terminal tab names)."
fi

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
# STEP 17: Bluetooth (controllers, headphones, peripherals)
# ============================================================
progress "Setting up Bluetooth..."

if [ -d /sys/class/bluetooth ] && [ -n "$(ls -A /sys/class/bluetooth 2>/dev/null)" ] || rfkill list bluetooth 2>/dev/null | grep -q .; then
    sudo rfkill unblock bluetooth 2>/dev/null
    sudo systemctl enable --now bluetooth 2>/dev/null && ok "Bluetooth service enabled."

    # Xbox / PlayStation pads over Bluetooth need L2CAP ERTM off on Linux.
    # Without this an Xbox One/Series controller pairs and then instantly drops.
    if [ ! -f /etc/modprobe.d/47os-bluetooth-controllers.conf ]; then
        echo "# 47OS: required for Xbox One/Series controllers over Bluetooth" | \
            sudo tee /etc/modprobe.d/47os-bluetooth-controllers.conf >/dev/null
        echo "options bluetooth disable_ertm=Y" | \
            sudo tee -a /etc/modprobe.d/47os-bluetooth-controllers.conf >/dev/null
        # Apply now too, so it works before the next reboot.
        echo Y | sudo tee /sys/module/bluetooth/parameters/disable_ertm >/dev/null 2>&1
        ok "Game controller pairing fix applied."
    fi

    # blueman is installed for its pairing window (blueman-manager, which the
    # panel applet opens), but blueman-applet is deliberately NOT autostarted:
    # its tray icon plugin cannot be disabled, so it would put a second
    # bluetooth icon in the panel next to the 47OS one.
    rm -f "$HOME/.config/autostart/blueman.desktop" 2>/dev/null
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/blueman.desktop" <<'BTOFF'
[Desktop Entry]
Type=Application
Name=Blueman Applet
Exec=/usr/bin/blueman-applet
X-GNOME-Autostart-enabled=false
Hidden=true
NoDisplay=true
BTOFF
    ok "Bluetooth applet ready (one icon, not two)."

else
    warn "No Bluetooth hardware detected — skipping Bluetooth setup."
fi

# ============================================================
# STEP 18: Face Unlock (laptops with an IR / Windows Hello camera)
# ============================================================
progress "Installing Face Unlock..."

# The engine itself is NOT installed here: it's ~100 packages and it only
# makes sense on a machine with the right camera. This installs the setup
# app; the user runs it once from Menu > Preferences > Face Unlock and it
# does detection, install, enrolment and testing on the actual hardware.
if [ -f "$SCRIPT_DIR/scripts/47os-face-unlock" ]; then
    install -m 0755 "$SCRIPT_DIR/scripts/47os-face-unlock" "$HOME/.local/bin/47os-face-unlock"
    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/47os-face-unlock.desktop" <<FACEDESK
[Desktop Entry]
Type=Application
Name=Face Unlock
GenericName=Face Recognition Login
Comment=Log in and authorise with your face, like Windows Hello
Exec=$HOME/.local/bin/47os-face-unlock
Icon=avatar-default-symbolic
Terminal=false
Categories=Settings;DesktopSettings;X-GNOME-PersonalSettings;
Keywords=face;unlock;login;hello;camera;biometric;security;
FACEDESK
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null
    ok "Face Unlock installed (Menu > Preferences > Face Unlock)."
else
    warn "Face Unlock script not found — skipping."
fi

# ============================================================
# STEP 19: Battery Saver mode + updater
# ============================================================
progress "Installing power tools..."

# Root half: exactly two allowed words, no paths. The sudoers rule below
# grants ONLY this binary, so the panel toggle is passwordless without
# handing the user session general root.
if [ -f "$SCRIPT_DIR/system/power/47os-powerctl" ]; then
    sudo install -m 0755 -o root -g root "$SCRIPT_DIR/system/power/47os-powerctl" /usr/local/bin/47os-powerctl
    echo "$USER ALL=(root) NOPASSWD: /usr/local/bin/47os-powerctl saver, /usr/local/bin/47os-powerctl balanced" \
        | sudo tee /etc/sudoers.d/47os-powermode >/dev/null
    sudo chmod 0440 /etc/sudoers.d/47os-powermode
    # A bad sudoers file locks sudo for everyone — validate and roll back if so.
    if ! sudo visudo -cf /etc/sudoers.d/47os-powermode >/dev/null 2>&1; then
        sudo rm -f /etc/sudoers.d/47os-powermode
        warn "sudoers rule rejected — Battery Saver will ask for a password."
    else
        ok "Battery Saver wired (passwordless, scoped to one command)."
    fi
fi

if [ -f "$SCRIPT_DIR/scripts/47os-powermode" ]; then
    install -m 0755 "$SCRIPT_DIR/scripts/47os-powermode" "$HOME/.local/bin/47os-powermode"
fi

# Repair: one command to put the desktop layout back without a reinstall.
if [ -f "$SCRIPT_DIR/scripts/47os-repair" ]; then
    install -m 0755 "$SCRIPT_DIR/scripts/47os-repair" "$HOME/.local/bin/47os-repair"
    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/47os-repair.desktop" <<REPDESK
[Desktop Entry]
Type=Application
Name=47OS Repair
Comment=Put the panel, applets and menu icon back the way they should be
Exec=alacritty -e $HOME/.local/bin/47os-repair
Icon=preferences-desktop
Terminal=false
Categories=System;Settings;
Keywords=repair;fix;panel;applet;47os;
REPDESK
    ok "Repair tool installed (run: 47os-repair)."
fi

# Updater: 47os-update from anywhere, no uninstall/reinstall dance.
if [ -f "$SCRIPT_DIR/update.sh" ]; then
    cat > "$HOME/.local/bin/47os-update" <<UPDWRAP
#!/usr/bin/env bash
# The checkout this was installed from. If you delete or move it, we do not
# die with "No such file" — we clone a fresh copy and update from that.
DIR="$SCRIPT_DIR"
if [ ! -f "\$DIR/update.sh" ]; then
    DIR="\$(cat "\$HOME/.config/47industries/install-path" 2>/dev/null)"
fi
if [ ! -f "\$DIR/update.sh" ]; then
    DIR="\$HOME/47os-rice"
    echo ":: Original 47OS checkout is gone — fetching a fresh one into \$DIR"
    rm -rf "\$DIR"
    git clone --depth 1 https://github.com/47-Industries/47os-rice.git "\$DIR" || {
        echo "  x Clone failed. Check your internet."; exit 1; }
fi
exec bash "\$DIR/update.sh" "\$@"
UPDWRAP
    chmod 0755 "$HOME/.local/bin/47os-update"
    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/47os-update.desktop" <<UPDDESK
[Desktop Entry]
Type=Application
Name=47OS Update
Comment=Pull the newest 47OS and re-apply it in place
Exec=alacritty -e $HOME/.local/bin/47os-update
Icon=system-software-update
Terminal=false
Categories=System;Settings;
Keywords=update;upgrade;47os;
UPDDESK
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null
    ok "Updater installed (run: 47os-update, or Menu > 47OS Update)."
fi

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
echo "  - 7 custom panel applets (battery, wifi, bluetooth, brightness, sound, etc.)"
echo "  - Bluetooth: controllers, headphones, peripherals (panel applet)"
echo "  - Face Unlock setup app (Menu > Preferences > Face Unlock)"
echo "  - Battery Saver toggle in the battery applet + charging pulse"
echo "  - 47os-update — updates in place, no uninstall needed"
echo "  - Wobbly windows + Glide open/close + Genie minimize"
echo "  - 47 Sound system (sounds on all actions)"
echo "  - Transparency toggle (Ctrl+Shift+T)"
echo "  - Matrix terminal splash screen"
echo "  - Keybindings (added alongside your existing ones)"
echo "  - Custom macOS-style login screen + boot splash"
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
