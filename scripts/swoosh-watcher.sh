#!/bin/bash
# Swoosh sound watcher - plays sounds on file downloads and deletions
# Rate-limited: one sound at a time, cooldown between plays

DOWNLOAD_SOUND="$HOME/.local/share/sounds/custom/download-swoosh.wav"
DELETE_SOUND="$HOME/.local/share/sounds/custom/delete-swoosh.wav"
COOLDOWN=2  # seconds between sounds

TRASH_DIR="$HOME/.local/share/Trash/files"
mkdir -p "$TRASH_DIR"

# Prevent duplicate instances
LOCKFILE="/tmp/swoosh-watcher-$UID.lock"
exec 200>"$LOCKFILE"
flock -n 200 || { echo "swoosh-watcher already running"; exit 1; }
echo $$ >&200

LAST_PLAY=0

play_sound() {
    local sound="$1"
    local now
    now=$(date +%s)
    if (( now - LAST_PLAY >= COOLDOWN )); then
        LAST_PLAY=$now
        47sound play "$sound" &
        wait $!
    fi
}

# Build list of existing watch dirs
DIRS=()
for d in "$HOME/Downloads" "$HOME/Documents" "$HOME/Pictures" "$HOME/Desktop" "$HOME/Music" "$HOME/Videos"; do
    [ -d "$d" ] && DIRS+=("$d")
done

# Watch for new files (downloads)
inotifywait -m -r -e create -e moved_to --format '%w%f' "${DIRS[@]}" 2>/dev/null | while read -r filepath; do
    filename=$(basename "$filepath")
    case "$filename" in
        .*|*.crdownload|*.part|*.tmp) continue ;;
    esac
    play_sound "$DOWNLOAD_SOUND"
done &

# Watch for trash (delete via file manager)
inotifywait -m -e create -e moved_to --format '%f' "$TRASH_DIR" 2>/dev/null | while read -r filename; do
    play_sound "$DELETE_SOUND"
done &

# Watch for direct deletions
inotifywait -m -r -e delete -e moved_from --format '%w%f' "${DIRS[@]}" 2>/dev/null | while read -r filepath; do
    filename=$(basename "$filepath")
    case "$filename" in
        .*|*.crdownload|*.part|*.tmp) continue ;;
    esac
    play_sound "$DELETE_SOUND"
done &

wait
