#!/usr/bin/env bash

STEP=5
SINK="@DEFAULT_AUDIO_SINK@"

# Check for wpctl (PipeWire)
if ! command -v wpctl &>/dev/null; then
    # Fallback to pactl (PulseAudio)
    case "$1" in
        up)   pactl set-sink-volume @DEFAULT_SINK@ "+${STEP}%" ;;
        down) pactl set-sink-volume @DEFAULT_SINK@ "-${STEP}%" ;;
        mute) pactl set-sink-mute @DEFAULT_SINK@ toggle ;;
    esac
    VOLUME=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+%' | head -1 | tr -d '%')
    MUTED=$(pactl get-sink-mute @DEFAULT_SINK@ | grep -c "yes")
    if [ "$MUTED" = "1" ]; then
        notify-send -h "int:value:$VOLUME" -h string:x-canonical-private-synchronous:volume "Volume" "Muted"
    else
        notify-send -h "int:value:$VOLUME" -h string:x-canonical-private-synchronous:volume "Volume" "${VOLUME}%"
    fi
    exit 0
fi

case "$1" in
  up)
    wpctl set-volume "$SINK" "${STEP}%+" >/dev/null
    ;;
  down)
    wpctl set-volume "$SINK" "${STEP}%-" >/dev/null
    ;;
  mute)
    wpctl set-mute "$SINK" toggle >/dev/null
    ;;
esac

# Get volume + mute state
INFO=$(wpctl get-volume "$SINK")
VOLUME=$(echo "$INFO" | awk '{print int($2 * 100)}')

if echo "$INFO" | grep -q MUTED; then
    TEXT="Muted"
else
    TEXT="${VOLUME}%"
fi

notify-send \
    -h "int:value:$VOLUME" \
    -h string:x-canonical-private-synchronous:volume \
    "Volume" "$TEXT"
