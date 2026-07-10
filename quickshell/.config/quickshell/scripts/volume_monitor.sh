#!/usr/bin/env bash

get_vol() {
  # Sink status
  sink_info=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
  if [ -z "$sink_info" ]; then
    sink_vol=0
    sink_muted=true
  else
    # Extract volume number and handle cases where it might be empty or not a float
    val=$(echo "$sink_info" | awk '{print $2}')
    if [[ -n "$val" ]]; then
      sink_vol=$(echo "$val" | awk '{print int($1 * 100)}')
    else
      sink_vol=0
    fi
    sink_muted=false
    if [[ "$sink_info" =~ "[MUTED]" ]]; then
      sink_muted=true
    fi
  fi

  # Source status
  source_info=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)
  if [ -z "$source_info" ]; then
    source_vol=0
    source_muted=true
  else
    val=$(echo "$source_info" | awk '{print $2}')
    if [[ -n "$val" ]]; then
      source_vol=$(echo "$val" | awk '{print int($1 * 100)}')
    else
      source_vol=0
    fi
    source_muted=false
    if [[ "$source_info" =~ "[MUTED]" ]]; then
      source_muted=true
    fi
  fi

  echo "{\"sink_vol\": $sink_vol, \"sink_muted\": $sink_muted, \"source_vol\": $source_vol, \"source_muted\": $source_muted}"
}

# Initial print
get_vol

# Reactive update using pactl subscribe
pactl subscribe 2>/dev/null | while read -r line; do
  if [[ "$line" =~ "Event 'change' on sink" || "$line" =~ "Event 'change' on source" ]]; then
    get_vol
  fi
done
