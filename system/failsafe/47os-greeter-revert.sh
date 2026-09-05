#!/bin/bash
# 47 OS greeter failsafe.
# Fires ONLY if lightdm failed to come up with the custom greeter.
# Restores the stock greeter so the machine can never be left
# at a black screen with no way to log in.
set -u
LOG=/var/log/47os-greeter-revert.log
exec >>"$LOG" 2>&1
echo "=== $(date -Is) greeter failsafe fired ==="

DROPIN=/etc/lightdm/lightdm.conf.d/50-greeter.conf
STOCK=""
for g in slick-greeter lightdm-gtk-greeter; do
    command -v "$g" &>/dev/null && STOCK="$g" && break
done
[ -z "$STOCK" ] && STOCK="lightdm-gtk-greeter"

# Drop the 47 greeter override
[ -f "$DROPIN" ] && mv "$DROPIN" "${DROPIN}.failed"

# Repair the main conf too (install.sh sed-edits it directly)
if [ -f /etc/lightdm/lightdm.conf ]; then
    sed -i "s/^greeter-session=.*/greeter-session=${STOCK}/" /etc/lightdm/lightdm.conf
fi

echo "reverted to ${STOCK}; restarting lightdm"
systemctl reset-failed lightdm.service 2>/dev/null
systemctl restart lightdm.service
