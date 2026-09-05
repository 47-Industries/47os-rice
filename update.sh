#!/usr/bin/env bash
# 47OS updater — pulls the latest rice and re-applies it in place.
# You do NOT uninstall first. Your files, accounts and settings are untouched;
# this only refreshes the 47OS pieces (applets, scripts, sounds, theme, system
# bits) and every run still takes a fresh timestamped backup first.
set -uo pipefail

CYAN='\033[38;2;0;255;255m'; GREEN='\033[38;2;0;255;150m'
YELLOW='\033[38;2;255;200;0m'; RED='\033[38;2;255;80;80m'
WHITE='\033[1;37m'; RESET='\033[0m'

say()  { echo -e "${CYAN}::${RESET} $1"; }
ok()   { echo -e "  ${GREEN}✓${RESET} $1"; }
warn() { echo -e "  ${YELLOW}!${RESET} $1"; }
die()  { echo -e "  ${RED}✗${RESET} $1"; exit 1; }

[ "$(id -u)" -eq 0 ] && die "Don't run this with sudo. Run it as yourself."

REPO_URL="https://github.com/47-Industries/47os-rice.git"

# Where is the checkout? install.sh records it; fall back to this script's dir.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECORDED="$(cat "$HOME/.config/47industries/install-path" 2>/dev/null)"
DIR="$SCRIPT_DIR"
[ -d "$RECORDED/.git" ] && DIR="$RECORDED"

echo ""
echo -e "${WHITE}  47OS Update${RESET}"
echo ""

if [ ! -d "$DIR/.git" ]; then
    warn "No git checkout found at $DIR — cloning a fresh one."
    DIR="$HOME/47os-rice"
    rm -rf "$DIR"
    git clone --depth 1 "$REPO_URL" "$DIR" || die "Clone failed. Check your internet."
    ok "Cloned to $DIR"
else
    say "Updating $DIR"
    BEFORE="$(git -C "$DIR" rev-parse --short HEAD 2>/dev/null)"

    # Never destroy local edits silently — stash them and say so.
    if ! git -C "$DIR" diff --quiet 2>/dev/null || ! git -C "$DIR" diff --cached --quiet 2>/dev/null; then
        STASH="47os-update-$(date +%Y%m%d-%H%M%S)"
        git -C "$DIR" stash push -u -m "$STASH" >/dev/null 2>&1 && \
            warn "You had local changes — stashed as '$STASH' (git stash list)."
    fi

    git -C "$DIR" fetch --depth 1 origin 2>/dev/null || die "Fetch failed. Check your internet."
    BRANCH="$(git -C "$DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    [ -z "$BRANCH" ] || [ "$BRANCH" = "HEAD" ] && BRANCH=master
    git -C "$DIR" reset --hard "origin/$BRANCH" >/dev/null 2>&1 || die "Update failed."

    AFTER="$(git -C "$DIR" rev-parse --short HEAD 2>/dev/null)"
    if [ "$BEFORE" = "$AFTER" ]; then
        ok "Already on the newest version ($AFTER)."
    else
        ok "Updated $BEFORE -> $AFTER"
        git -C "$DIR" log --oneline "$BEFORE..$AFTER" 2>/dev/null | sed 's/^/      /' | head -20
    fi
fi

echo ""
say "Re-applying 47OS..."
echo ""

bash "$DIR/install.sh" || die "The installer reported a problem. Nothing was uninstalled — you can re-run this."

echo ""
ok "Update complete."
echo -e "${WHITE}  Restart Cinnamon to pick up applet changes:${RESET} Ctrl+Alt+Esc"
echo -e "${WHITE}  (or just log out and back in)${RESET}"
echo ""
