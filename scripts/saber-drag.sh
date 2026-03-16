#!/usr/bin/env bash
# 47 Industries - Air Swoosh Window Drag Effect
# Quick wind/air sounds when dragging windows

SOUND_DIR="$HOME/.local/share/47industries/sounds"

SOUNDS=(
    "$SOUND_DIR/air-whoosh-1.mp3"
    "$SOUND_DIR/air-whoosh-2.mp3"
    "$SOUND_DIR/air-whoosh-3.mp3"
    "$SOUND_DIR/air-swish-1.mp3"
    "$SOUND_DIR/air-swoosh-1.mp3"
    "$SOUND_DIR/air-swoosh-2.mp3"
)

THRESHOLD=60
COOLDOWN_MS=350
POLL=0.03

prev_x=""
prev_win=""
last_sound_time=0
last_idx=-1
accumulated_delta=0

trap 'exit 0' SIGTERM SIGINT

pick_sound() {
    local len=${#SOUNDS[@]}
    local idx
    while true; do
        idx=$(( RANDOM % len ))
        if [[ "$idx" != "$last_idx" || "$len" -eq 1 ]]; then
            last_idx=$idx
            echo "${SOUNDS[$idx]}"
            return
        fi
    done
}

now_ms() {
    date +%s%N | cut -b1-13
}

while true; do
    win_id=$(xdotool getactivewindow 2>/dev/null) || { sleep 0.1; continue; }
    win_info=$(xdotool getwindowgeometry "$win_id" 2>/dev/null) || { sleep 0.1; continue; }
    current_x=$(echo "$win_info" | grep "Position:" | sed 's/.*Position: \([0-9-]*\),.*/\1/')

    if [[ -z "$current_x" ]]; then
        sleep "$POLL"
        continue
    fi

    if [[ "$win_id" != "$prev_win" ]]; then
        prev_win="$win_id"
        prev_x="$current_x"
        accumulated_delta=0
        sleep "$POLL"
        continue
    fi

    if [[ -n "$prev_x" && "$prev_x" != "$current_x" ]]; then
        delta=$((current_x - prev_x))
        abs_delta=${delta#-}

        if [[ "$abs_delta" -gt 2 && "$abs_delta" -lt 2000 ]]; then
            if [[ "$delta" -gt 0 && "$accumulated_delta" -lt 0 ]] || \
               [[ "$delta" -lt 0 && "$accumulated_delta" -gt 0 ]]; then
                accumulated_delta=0
            fi
            accumulated_delta=$((accumulated_delta + delta))
            abs_accumulated=${accumulated_delta#-}

            if [[ "$abs_accumulated" -ge "$THRESHOLD" ]]; then
                now=$(now_ms)
                elapsed=$((now - last_sound_time))

                if [[ "$elapsed" -ge "$COOLDOWN_MS" ]]; then
                    47sound play "$(pick_sound)" &
                    last_sound_time=$now
                fi
                accumulated_delta=0
            fi
        fi
    else
        accumulated_delta=0
    fi

    prev_x="$current_x"
    sleep "$POLL"
done
