#!/bin/bash

# ============================================================
#   47 OS Rice Uninstaller
#   Restores your system to its pre-47OS state
# ============================================================

CYAN='\033[1;36m'
WHITE='\033[1;97m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
RESET='\033[0m'

echo -e "${CYAN}"
echo "================================================"
echo "  47 Industries Rice Uninstaller"
echo "================================================"
echo -e "${RESET}"

# Find the backup directory
BACKUP_PATH_FILE="$HOME/.config/47industries/backup-path"
if [ -f "$BACKUP_PATH_FILE" ]; then
    BACKUP_DIR=$(cat "$BACKUP_PATH_FILE")
else
    # Try to find the most recent backup
    BACKUP_DIR=$(ls -td "$HOME/.47os-backup/"* 2>/dev/null | head -1)
fi

if [ -z "$BACKUP_DIR" ] || [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}No backup found. Cannot restore automatically.${RESET}"
    echo "You can manually reset Cinnamon to defaults with:"
    echo "  dconf reset -f /org/cinnamon/"
    exit 1
fi

echo "Backup found: $BACKUP_DIR"
echo ""
echo "This will:"
echo "  - Restore your original Cinnamon settings"
echo "  - Remove 47OS keybindings"
echo "  - Remove 47OS autostart entries"
echo "  - Remove 47OS panel applets"
echo "  - Restore your login screen config"
echo "  - Remove 47OS scripts and sounds"
echo "  - Restore default boot splash and GRUB settings"
echo ""
echo "It will NOT remove:"
echo "  - WhiteSur theme/icons (they don't hurt anything)"
echo "  - SF Pro fonts (other apps might use them)"
echo ""
read -p "Continue? [y/N] " confirm
[[ "$confirm" != "y" && "$confirm" != "Y" ]] && echo "Aborted." && exit 0

echo ""

# ============================================================
# 1. Restore gsettings
# ============================================================
echo -e "${CYAN}[1/10]${WHITE} Restoring Cinnamon settings...${RESET}"
if [ -f "$BACKUP_DIR/gsettings-restore.sh" ]; then
    bash "$BACKUP_DIR/gsettings-restore.sh" 2>/dev/null
    echo -e "  ${GREEN}Settings restored.${RESET}"
else
    echo -e "  ${YELLOW}No gsettings backup found, skipping.${RESET}"
fi

# ============================================================
# 2. Remove 47OS keybindings
# ============================================================
echo -e "\n${CYAN}[2/10]${WHITE} Removing 47OS keybindings...${RESET}"
if [ -f "$BACKUP_DIR/keybindings-dconf.dump" ]; then
    dconf reset -f /org/cinnamon/desktop/keybindings/custom-keybindings/ 2>/dev/null
    dconf load /org/cinnamon/desktop/keybindings/ < "$BACKUP_DIR/keybindings-dconf.dump" 2>/dev/null
    echo -e "  ${GREEN}Original keybindings restored.${RESET}"
else
    # Just remove the 47- prefixed ones
    CURRENT_LIST=$(dconf read /org/cinnamon/desktop/keybindings/custom-list 2>/dev/null)
    if [ -n "$CURRENT_LIST" ]; then
        # Find and remove 47OS keybindings by checking for "47-" prefix in name
        for path in $(echo "$CURRENT_LIST" | grep -oE "'/org/cinnamon/desktop/keybindings/custom-keybindings/custom[0-9]+/'"); do
            clean_path=$(echo "$path" | tr -d "'")
            name=$(dconf read "${clean_path}name" 2>/dev/null)
            if echo "$name" | grep -q "^'47-"; then
                dconf reset -f "$clean_path" 2>/dev/null
            fi
        done
    fi
    echo -e "  ${GREEN}47OS keybindings removed.${RESET}"
fi

# ============================================================
# 3. Remove 47OS autostart entries
# ============================================================
echo -e "\n${CYAN}[3/10]${WHITE} Removing 47OS autostart entries...${RESET}"
for f in 47glass-inject 47sound-inject saber-drag swoosh-watcher \
         window-close-sound window-state-sound battery-monitor \
         dynamic-wallpaper brightness-tracker volume-tracker \
         middle-click-hold 47os-first-login; do
    rm -f "$HOME/.config/autostart/${f}.desktop"
done
echo -e "  ${GREEN}Done.${RESET}"

# ============================================================
# 4. Restore backed-up config files
# ============================================================
echo -e "\n${CYAN}[4/10]${WHITE} Restoring config files...${RESET}"

# Restore .bashrc — remove the 47OS lines
if [ -f "$BACKUP_DIR/.bashrc" ]; then
    cp "$BACKUP_DIR/.bashrc" "$HOME/.bashrc"
    echo "  .bashrc restored."
else
    # Just remove 47OS lines
    sed -i '/# 47 Industries Terminal Splash/d' "$HOME/.bashrc" 2>/dev/null
    sed -i '/matrix-47\.py/d' "$HOME/.bashrc" 2>/dev/null
    echo "  Removed 47OS lines from .bashrc."
fi

# Restore .xbindkeysrc
if [ -f "$BACKUP_DIR/.xbindkeysrc" ]; then
    cp "$BACKUP_DIR/.xbindkeysrc" "$HOME/.xbindkeysrc"
    echo "  .xbindkeysrc restored."
fi

# Restore gtk.css
if [ -f "$BACKUP_DIR/.config/gtk-3.0/gtk.css" ]; then
    cp "$BACKUP_DIR/.config/gtk-3.0/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"
    echo "  gtk.css restored."
else
    # Remove 47OS section
    sed -i '/\/\* 47os-rice start \*\//,/\/\* 47os-rice end \*\//d' "$HOME/.config/gtk-3.0/gtk.css" 2>/dev/null
fi

echo -e "  ${GREEN}Done.${RESET}"

# ============================================================
# 5. Restore login screen
# ============================================================
echo -e "\n${CYAN}[5/10]${WHITE} Restoring login screen...${RESET}"
if [ -f "$BACKUP_DIR/slick-greeter.conf.bak" ]; then
    sudo cp "$BACKUP_DIR/slick-greeter.conf.bak" /etc/lightdm/slick-greeter.conf
    echo -e "  ${GREEN}Login screen restored.${RESET}"
else
    echo -e "  ${YELLOW}No login screen backup found. You may need to reconfigure manually.${RESET}"
fi

# Restore main lightdm.conf (web-greeter → slick-greeter)
if [ -f "$BACKUP_DIR/lightdm.conf.bak" ]; then
    sudo cp "$BACKUP_DIR/lightdm.conf.bak" /etc/lightdm/lightdm.conf
elif [ -f /etc/lightdm/lightdm.conf ]; then
    sudo sed -i 's/^greeter-session=web-greeter/greeter-session=slick-greeter/' /etc/lightdm/lightdm.conf
    sudo sed -i 's/^greeter-session=nody-greeter/greeter-session=slick-greeter/' /etc/lightdm/lightdm.conf
fi

# Restore web-greeter config
if [ -f "$BACKUP_DIR/web-greeter.yml.bak" ]; then
    sudo cp "$BACKUP_DIR/web-greeter.yml.bak" /etc/lightdm/web-greeter.yml
fi
if [ -f "$BACKUP_DIR/50-greeter.conf.bak" ]; then
    sudo cp "$BACKUP_DIR/50-greeter.conf.bak" /etc/lightdm/lightdm.conf.d/50-greeter.conf
else
    sudo rm -f /etc/lightdm/lightdm.conf.d/50-greeter.conf 2>/dev/null
fi
sudo rm -rf /usr/share/web-greeter/themes/47-macos 2>/dev/null
sudo rm -rf /usr/share/nody-greeter/themes/47-macos 2>/dev/null

# Remove theme enforcement
sudo rm -f /etc/xdg/autostart/47os-force-theme.desktop 2>/dev/null
sudo rm -f /usr/local/bin/47os-force-theme.sh 2>/dev/null
sudo rm -f /usr/share/glib-2.0/schemas/zz_47os.gschema.override 2>/dev/null
sudo glib-compile-schemas /usr/share/glib-2.0/schemas/ 2>/dev/null
sudo rm -f /etc/dconf/db/local.d/00-47os-defaults 2>/dev/null
sudo dconf update 2>/dev/null
sudo rm -f /etc/lightdm/lightdm.conf.d/51-cursor.conf 2>/dev/null

echo -e "  ${GREEN}System overrides removed.${RESET}"

# ============================================================
# 6. Remove 47OS scripts and data
# ============================================================
echo -e "\n${CYAN}[6/10]${WHITE} Removing 47OS scripts and sounds...${RESET}"

# Scripts in ~/.local/bin
for script in 47sound 47transparency 47glass-inject.sh \
              matrix-47.py saber-drag.sh swoosh-watcher.sh 47sound-inject.sh \
              middle-click-hold.py; do
    rm -f "$HOME/.local/bin/$script"
done

# Kill any running 47OS background processes
pkill -f saber-drag.sh 2>/dev/null
pkill -f swoosh-watcher.sh 2>/dev/null
pkill -f window-close-sound.py 2>/dev/null
pkill -f window-state-sound.py 2>/dev/null
pkill -f 47glass-inject.sh 2>/dev/null
pkill -f 47sound-inject.sh 2>/dev/null
pkill -f middle-click-hold.py 2>/dev/null
pkill -f battery-monitor.sh 2>/dev/null
pkill -f brightness-tracker.sh 2>/dev/null
pkill -f volume-tracker.sh 2>/dev/null
pkill -f dynamic-wallpaper.sh 2>/dev/null

# Remove 47OS data directories
rm -rf "$HOME/Documents/47industries" 2>/dev/null
rm -rf "$HOME/.local/share/47industries" 2>/dev/null
rm -rf "$HOME/.config/47industries" 2>/dev/null

# Remove Rofi spotlight theme
rm -f "$HOME/.config/rofi/themes/spotlight.rasi" 2>/dev/null

# Remove devilspie2 transparency rules
rm -f "$HOME/.config/devilspie2/transparency.lua" 2>/dev/null

# Remove Nemo actions
rm -f "$HOME/.local/share/nemo/actions/extract-here.nemo_action" 2>/dev/null
rm -f "$HOME/.local/share/nemo/actions/trash-sound.nemo_action" 2>/dev/null

# Remove auto-extract handler and SoundCloud webapp
rm -f "$HOME/.local/share/applications/auto-extract.desktop" 2>/dev/null
rm -f "$HOME/.local/share/applications/soundcloud.desktop" 2>/dev/null
xdg-mime default org.gnome.FileRoller.desktop application/zip 2>/dev/null

# Restore mimeapps.list if backed up
if [ -f "$BACKUP_DIR/.config/mimeapps.list" ]; then
    cp "$BACKUP_DIR/.config/mimeapps.list" "$HOME/.config/mimeapps.list"
fi

# Remove Plank dock launchers (47OS-specific ones)
rm -rf "$HOME/.config/plank/dock1/launchers" 2>/dev/null

# Remove fastfetch config
rm -f "$HOME/.config/fastfetch/config.jsonc" 2>/dev/null

# Remove user avatar
rm -f "$HOME/.face" 2>/dev/null

echo -e "  ${GREEN}Done.${RESET}"

# ============================================================
# 7. Remove custom applets
# ============================================================
echo -e "\n${CYAN}[7/10]${WHITE} Removing custom Cinnamon applets...${RESET}"
for applet in brightness@custom fake-battery@custom \
              fake-wifi@custom 47sound@custom vpn-toggle@custom sound@cinnamon.org; do
    rm -rf "$HOME/.local/share/cinnamon/applets/$applet"
done
echo -e "  ${GREEN}Done.${RESET}"

# ============================================================
# 8. Remove Cinnamon extensions
# ============================================================
echo -e "\n${CYAN}[8/10]${WHITE} Removing Cinnamon extensions...${RESET}"
for ext in compiz-windows-effect@hermes83.github.com CinnamonBurnMyWindows@klangman CinnamonMagicLamp@klangman; do
    rm -rf "$HOME/.local/share/cinnamon/extensions/$ext"
done
rm -rf "$HOME/.config/cinnamon/spices/CinnamonBurnMyWindows@klangman" 2>/dev/null
rm -rf "$HOME/.config/cinnamon/spices/CinnamonMagicLamp@klangman" 2>/dev/null
echo -e "  ${GREEN}Done.${RESET}"

# ============================================================
# 9. Restore Plymouth boot splash
# ============================================================
echo -e "\n${CYAN}[9/10]${WHITE} Restoring default boot splash...${RESET}"
if [ -d /usr/share/plymouth/themes/47-logo ]; then
    sudo update-alternatives --remove default.plymouth \
        /usr/share/plymouth/themes/47-logo/47-logo.plymouth 2>/dev/null
    sudo rm -rf /usr/share/plymouth/themes/47-logo
    sudo update-initramfs -u 2>/dev/null
    echo -e "  ${GREEN}Plymouth restored to default.${RESET}"
else
    echo -e "  ${YELLOW}47-logo Plymouth theme not found, skipping.${RESET}"
fi

# ============================================================
# 10. Restore GRUB defaults
# ============================================================
echo -e "\n${CYAN}[10/10]${WHITE} Restoring GRUB settings...${RESET}"
if [ -f "$BACKUP_DIR/grub.default.bak" ]; then
    sudo cp "$BACKUP_DIR/grub.default.bak" /etc/default/grub
    sudo update-grub 2>/dev/null
    echo -e "  ${GREEN}GRUB restored from backup.${RESET}"
else
    # Restore reasonable defaults
    sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub 2>/dev/null
    sudo sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub 2>/dev/null
    sudo sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Linux Mint"/' /etc/default/grub 2>/dev/null
    sudo update-grub 2>/dev/null
    echo -e "  ${GREEN}GRUB restored to Linux Mint defaults.${RESET}"
fi

# ============================================================
# DONE
# ============================================================
echo ""
echo -e "${CYAN}================================================${RESET}"
echo -e "${GREEN}  47 OS rice has been removed.${RESET}"
echo -e "${CYAN}================================================${RESET}"
echo ""
echo "Log out and back in for all changes to take effect."
echo ""
echo "Note: WhiteSur theme, icons, and fonts were left installed"
echo "since they don't affect anything. To remove them too:"
echo "  rm -rf ~/.themes/WhiteSur-*"
echo "  rm -rf ~/.local/share/icons/WhiteSur-*"
echo ""
