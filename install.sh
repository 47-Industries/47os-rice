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
    brightnessctl pulseaudio-utils \
    inotify-tools devilspie2 macchanger x11-utils \
    python3 jq curl wget git dconf-cli \
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

# ============================================================
# STEP 2: Install WhiteSur GTK Theme
# ============================================================
progress "Installing WhiteSur GTK theme..."
if [ -d "$HOME/.themes/WhiteSur-Dark" ]; then
    ok "WhiteSur-Dark theme already installed, skipping download."
else
    cd /tmp
    rm -rf WhiteSur-gtk-theme
    if git clone --depth 1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git 2>/dev/null; then
        cd WhiteSur-gtk-theme
        if ./install.sh -c Dark -s standard -l --round 2>/dev/null; then
            ok "WhiteSur GTK theme installed."
        else
            # Try simpler install flags
            ./install.sh -c Dark 2>/dev/null && ok "WhiteSur GTK theme installed (basic)." || fail "WhiteSur theme install failed."
        fi
        cd "$SCRIPT_DIR"
    else
        fail "Could not clone WhiteSur theme. Check internet connection."
        echo -e "  ${RED}The WhiteSur theme is required. Install will continue but the desktop may look broken.${RESET}"
        echo -e "  ${RED}Re-run this script once you have internet access.${RESET}"
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
    # Initialize transparency state to off
    echo "off" > /tmp/transparency_state
fi

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

ok "Done."

# ============================================================
# STEP 6: Install scripts to ~/.local/bin
# ============================================================
progress "Installing 47 Industries scripts..."
mkdir -p "$HOME/.local/bin"

for script in 47sound 47transparency 47glass-inject.sh ghost-mode.sh \
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
              fullscreen-toggle.sh lock-screen.sh powermenu.sh app-search.sh; do
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

for applet in ghost-mode@custom brightness@custom fake-battery@custom \
              fake-wifi@custom 47sound@custom vpn-toggle@custom; do
    if [ -d "$SCRIPT_DIR/applets/$applet" ]; then
        cp -r "$SCRIPT_DIR/applets/$applet" "$APPLET_DIR/"
    else
        warn "Applet not found: $applet"
    fi
done

ok "6 custom applets installed."

# ============================================================
# STEP 8: Install Cinnamon extension (wobbly windows)
# ============================================================
progress "Installing Cinnamon extensions..."
EXT_DIR="$HOME/.local/share/cinnamon/extensions/compiz-windows-effect@hermes83.github.com"
mkdir -p "$EXT_DIR"
cp -r "$SCRIPT_DIR/extensions/"* "$EXT_DIR/" 2>/dev/null
ok "Compiz wobbly windows effect installed."

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

# Fastfetch
mkdir -p "$HOME/.config/fastfetch"
cp "$SCRIPT_DIR/config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/"

# Cinnamon spices configs (calendar format, wobbly windows tuning)
mkdir -p "$HOME/.config/cinnamon/spices/calendar@cinnamon.org"
cp "$SCRIPT_DIR/config/cinnamon/calendar@cinnamon.org/13.json" "$HOME/.config/cinnamon/spices/calendar@cinnamon.org/"
mkdir -p "$HOME/.config/cinnamon/spices/compiz-windows-effect@hermes83.github.com"
cp "$SCRIPT_DIR/config/cinnamon/compiz-windows-effect@hermes83.github.com/"*.json "$HOME/.config/cinnamon/spices/compiz-windows-effect@hermes83.github.com/" 2>/dev/null

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
echo -e "[SeatDefaults]\ncursor-theme=WhiteSur-cursors\ncursor-theme-size=24" | \
    sudo tee /etc/lightdm/lightdm.conf.d/51-cursor.conf > /dev/null 2>/dev/null

# Plymouth boot splash (47 logo on boot)
if [ -d "$SCRIPT_DIR/system/plymouth/47-logo" ]; then
    sudo cp -r "$SCRIPT_DIR/system/plymouth/47-logo" /usr/share/plymouth/themes/
    sudo plymouth-set-default-theme 47-logo 2>/dev/null
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

# dconf system defaults
sudo mkdir -p /etc/dconf/db/local.d
sudo cp "$SCRIPT_DIR/system/dconf/00-47os-defaults" /etc/dconf/db/local.d/ 2>/dev/null
sudo dconf update 2>/dev/null

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

cat > "$HOME/.config/47industries/apply-rice.sh" <<APPLYSCRIPT
#!/bin/bash
# 47OS Rice - First Login Apply Script
# Runs once on first login after install, then removes itself.
# This prevents Cinnamon from crashing during live dconf changes.

sleep 3  # Wait for Cinnamon to fully load

# ---- THEME ----
gsettings set org.cinnamon.theme name 'WhiteSur-Dark'
gsettings set org.cinnamon.desktop.interface gtk-theme 'WhiteSur-Dark'
gsettings set org.cinnamon.desktop.interface icon-theme 'WhiteSur-dark'
gsettings set org.cinnamon.desktop.interface cursor-theme 'WhiteSur-cursors'
gsettings set org.cinnamon.desktop.interface font-name 'SF Pro Display 10'
gsettings set org.cinnamon.desktop.wm.preferences theme 'WhiteSur-Dark'
gsettings set org.cinnamon.desktop.wm.preferences titlebar-font 'SF Pro Display Bold 10'
gsettings set org.cinnamon.desktop.wm.preferences button-layout ':minimize,maximize,close'
gsettings set org.cinnamon.desktop.background picture-uri 'file:///usr/share/backgrounds/sequoia-sunrise.jpg'
gsettings set org.cinnamon.desktop.background picture-options 'zoom'
gsettings set org.gnome.desktop.interface gtk-theme 'WhiteSur-Dark' 2>/dev/null
gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark' 2>/dev/null
gsettings set org.gnome.desktop.interface cursor-theme 'WhiteSur-cursors' 2>/dev/null

# ---- PANEL ----
gsettings set org.cinnamon panels-enabled "['1:0:top']"
gsettings set org.cinnamon panels-height "['1:28']"
gsettings set org.cinnamon panel-scale-text-icons true
gsettings set org.cinnamon app-menu-icon-name '47os-logo'
gsettings set org.cinnamon system-icon '47os-logo'
dconf write /org/cinnamon/panel-zone-icon-sizes "'[{\"panelId\": 1, \"left\": 22, \"center\": 0, \"right\": 24}]'"
dconf write /org/cinnamon/panel-zone-symbolic-icon-sizes "'[{\"panelId\": 1, \"left\": 28, \"center\": 28, \"right\": 16}]'"
dconf write /org/cinnamon/next-applet-id 22

# ---- APPLETS ----
gsettings set org.cinnamon enabled-applets "['panel1:left:0:menu@cinnamon.org:0', 'panel1:right:0:systray@cinnamon.org:3', 'panel1:right:1:notifications@cinnamon.org:5', 'panel1:right:2:keyboard@cinnamon.org:8', 'panel1:right:3:ghost-mode@custom:18', 'panel1:right:4:brightness@custom:20', 'panel1:right:5:fake-wifi@custom:17', 'panel1:right:6:sound@cinnamon.org:11', 'panel1:right:7:fake-battery@custom:16', 'panel1:right:8:calendar@cinnamon.org:13']"
gsettings set org.cinnamon enabled-extensions "['compiz-windows-effect@hermes83.github.com']"

# ---- EFFECTS ----
gsettings set org.cinnamon desktop-effects true
gsettings set org.cinnamon desktop-effects-close 'scale'
gsettings set org.cinnamon desktop-effects-map 'scale'
gsettings set org.cinnamon desktop-effects-minimize 'traditional'
gsettings set org.cinnamon desktop-effects-on-dialogs true
gsettings set org.cinnamon desktop-effects-on-menus true
dconf write /org/cinnamon/startup-animation false
dconf write /org/cinnamon/enable-vfade false
dconf write /org/cinnamon/window-effect-speed 2
dconf write /org/cinnamon/enable-animations true
dconf write /org/cinnamon/hotcorner-layout "['expo:false:0', 'scale:false:0', 'scale:true:0', 'desktop:false:0']"

# ---- NEMO / DESKTOP ----
gsettings set org.nemo.desktop computer-icon-visible false
gsettings set org.nemo.desktop home-icon-visible false
gsettings set org.nemo.desktop network-icon-visible false
gsettings set org.nemo.desktop trash-icon-visible false
gsettings set org.nemo.desktop volumes-visible false
gsettings set org.nemo.desktop font 'SF Pro Display 10'

# ---- MUFFIN COMPOSITOR ----
dconf write /org/cinnamon/muffin/draggable-border-width 10
dconf write /org/cinnamon/muffin/edge-tiling false
dconf write /org/cinnamon/muffin/placement-mode "'pointer'"
dconf write /org/cinnamon/muffin/unredirect-fullscreen-windows true

# ---- SCREENSAVER / LOCK ----
dconf write /org/cinnamon/desktop/screensaver/lock-enabled false
dconf write /org/cinnamon/desktop/screensaver/lock-delay "uint32 0"
dconf write /org/cinnamon/desktop/screensaver/allow-media-control false
dconf write /org/cinnamon/desktop/screensaver/floating-widgets false
dconf write /org/cinnamon/desktop/screensaver/show-album-art false
dconf write /org/cinnamon/desktop/screensaver/show-info-panel true
dconf write /org/cinnamon/desktop/screensaver/show-notifications false
dconf write /org/cinnamon/desktop/screensaver/font-date "'%A, %B %-d'"
dconf write /org/cinnamon/desktop/screensaver/font-time "'%-I:%M %p'"

# ---- SOUND / KEYBOARD / POWER ----
dconf write /org/cinnamon/desktop/sound/event-sounds false
dconf write /org/cinnamon/desktop/peripherals/keyboard/numlock-state true
dconf write /org/cinnamon/desktop/peripherals/keyboard/delay "uint32 500"
dconf write /org/cinnamon/desktop/peripherals/keyboard/repeat-interval "uint32 30"
dconf write /org/cinnamon/settings-daemon/plugins/power/sleep-display-ac 0

# ---- DISABLE CONFLICTING KEYBINDINGS ----
dconf write /org/cinnamon/desktop/keybindings/media-keys/screensaver "['']"
dconf write /org/cinnamon/desktop/keybindings/media-keys/terminal "['']"

# ---- TOUCHPAD GESTURES ----
dconf write /org/cinnamon/gestures/swipe-down-2 "'PUSH_TILE_DOWN::end'"
dconf write /org/cinnamon/gestures/swipe-down-3 "'TOGGLE_OVERVIEW::end'"
dconf write /org/cinnamon/gestures/swipe-down-4 "'VOLUME_DOWN::end'"
dconf write /org/cinnamon/gestures/swipe-left-2 "'PUSH_TILE_LEFT::end'"
dconf write /org/cinnamon/gestures/swipe-left-3 "'WORKSPACE_NEXT::end'"
dconf write /org/cinnamon/gestures/swipe-left-4 "'WINDOW_WORKSPACE_PREVIOUS::end'"
dconf write /org/cinnamon/gestures/swipe-right-2 "'PUSH_TILE_RIGHT::end'"
dconf write /org/cinnamon/gestures/swipe-right-3 "'WORKSPACE_PREVIOUS::end'"
dconf write /org/cinnamon/gestures/swipe-right-4 "'WINDOW_WORKSPACE_NEXT::end'"
dconf write /org/cinnamon/gestures/swipe-up-2 "'PUSH_TILE_UP::end'"
dconf write /org/cinnamon/gestures/swipe-up-3 "'TOGGLE_EXPO::end'"
dconf write /org/cinnamon/gestures/swipe-up-4 "'VOLUME_UP::end'"
dconf write /org/cinnamon/gestures/tap-3 "'MEDIA_PLAY_PAUSE::end'"

# ---- CUSTOM KEYBINDINGS ----
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom0/name "'47-Launch Terminal'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom0/command "'$HOME/Documents/47industries/launch-terminal.sh'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom0/binding "['<Primary><Alt>t']"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom1/name "'47-Volume Up'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom1/command "'$HOME/Documents/47industries/volume-tracker.sh up'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom1/binding "['F10']"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom2/name "'47-Volume Down'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom2/command "'$HOME/Documents/47industries/volume-tracker.sh down'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom2/binding "['F9']"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom3/name "'47-Volume Mute'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom3/command "'$HOME/Documents/47industries/volume-tracker.sh mute'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom3/binding "['F8']"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom4/name "'47-Brightness Down'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom4/command "'$HOME/Documents/47industries/brightness-tracker.sh down'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom4/binding "['F2']"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom5/name "'47-Brightness Up'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom5/command "'$HOME/Documents/47industries/brightness-tracker.sh up'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom5/binding "['F3']"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom6/name "'47-Toggle Transparency'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom6/command "'$HOME/Documents/47industries/toggle-transparency.sh'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom6/binding "['<Primary><Shift>t']"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom7/name "'47-Close Window'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom7/command "'$HOME/Documents/47industries/close-window.sh'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom7/binding "['<Primary>q']"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom8/name "'47-Toggle Fullscreen'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom8/command "'$HOME/Documents/47industries/fullscreen-toggle.sh'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom8/binding "['<Primary><Shift>f']"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom9/name "'47-Lock Screen'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom9/command "'$HOME/Documents/47industries/lock-screen.sh'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom9/binding "['<Primary><Shift>l']"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom10/name "'47-Maximize Window'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom10/command "'$HOME/Documents/47industries/maximize-window.sh'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom10/binding "['<Primary><Shift>Up']"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom11/name "'47-Minimize Window'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom11/command "'$HOME/Documents/47industries/minimize-window.sh'"
dconf write /org/cinnamon/desktop/keybindings/custom-keybindings/custom11/binding "['<Primary><Shift>Down']"
dconf write /org/cinnamon/desktop/keybindings/custom-list "['/org/cinnamon/desktop/keybindings/custom-keybindings/custom0/', '/org/cinnamon/desktop/keybindings/custom-keybindings/custom1/', '/org/cinnamon/desktop/keybindings/custom-keybindings/custom2/', '/org/cinnamon/desktop/keybindings/custom-keybindings/custom3/', '/org/cinnamon/desktop/keybindings/custom-keybindings/custom4/', '/org/cinnamon/desktop/keybindings/custom-keybindings/custom5/', '/org/cinnamon/desktop/keybindings/custom-keybindings/custom6/', '/org/cinnamon/desktop/keybindings/custom-keybindings/custom7/', '/org/cinnamon/desktop/keybindings/custom-keybindings/custom8/', '/org/cinnamon/desktop/keybindings/custom-keybindings/custom9/', '/org/cinnamon/desktop/keybindings/custom-keybindings/custom10/', '/org/cinnamon/desktop/keybindings/custom-keybindings/custom11/']"

# ---- PLANK DOCK ----
dconf write /net/launchpad/plank/docks/dock1/alignment "'center'"
dconf write /net/launchpad/plank/docks/dock1/hide-mode "'intelligent'"
dconf write /net/launchpad/plank/docks/dock1/icon-size 52
dconf write /net/launchpad/plank/docks/dock1/items-alignment "'center'"
dconf write /net/launchpad/plank/docks/dock1/lock-items false
dconf write /net/launchpad/plank/docks/dock1/offset 0
dconf write /net/launchpad/plank/docks/dock1/position "'bottom'"
dconf write /net/launchpad/plank/docks/dock1/pressure-reveal false
dconf write /net/launchpad/plank/docks/dock1/theme "'Transparent'"
dconf write /net/launchpad/plank/docks/dock1/zoom-enabled true
dconf write /net/launchpad/plank/docks/dock1/zoom-percent 175
dconf write /net/launchpad/plank/docks/dock1/dock-items "['03-terminal.dockitem', 'brave-browser.dockitem', '04-mail.dockitem', '05-maps.dockitem', '07-camera.dockitem', '06-photos.dockitem', '08-contacts.dockitem', '10-editor.dockitem', '12-calculator.dockitem', '14-clocks.dockitem', '15-drawing.dockitem', '16-scanner.dockitem', '11-music.dockitem', 'nemo.dockitem', '17-settings.dockitem']"

# ---- MENU ICON CONFIG ----
mkdir -p "\$HOME/.config/cinnamon/spices/menu@cinnamon.org"
cat > "\$HOME/.config/cinnamon/spices/menu@cinnamon.org/0.json" <<'MENUCFG'
{
    "menu-icon-custom": {"type": "checkbox", "default": true, "value": true},
    "menu-icon": {"type": "iconfilechooser", "default": "", "value": "HOMEDIR/Documents/47industries/panel-icon.png"},
    "menu-icon-size": {"type": "spinbutton", "default": 28, "value": 32}
}
MENUCFG
sed -i "s|HOMEDIR|\$HOME|g" "\$HOME/.config/cinnamon/spices/menu@cinnamon.org/0.json"

# ---- RESTART CINNAMON TO APPLY ----
sleep 1
nohup cinnamon --replace > /dev/null 2>&1 &

# ---- SELF-DESTRUCT: Remove this autostart entry ----
rm -f "\$HOME/.config/autostart/47os-first-login.desktop"

notify-send "47 Industries" "Rice applied successfully! All features active." -i dialog-information
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
