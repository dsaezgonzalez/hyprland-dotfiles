#!/usr/bin/env bash

get_net() {
  # Get Wi-Fi radio status (enabled/disabled)
  wifi_status=$(nmcli radio wifi 2>/dev/null)
  if [ "$wifi_status" = "enabled" ]; then
    wifi_powered="true"
  else
    wifi_powered="false"
  fi

  active_dev=$(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device | grep ":connected:" | head -n1 2>/dev/null)
  if [ -n "$active_dev" ]; then
    dev=$(echo "$active_dev" | cut -d: -f1)
    type=$(echo "$active_dev" | cut -d: -f2)
    conn=$(echo "$active_dev" | cut -d: -f4)
    if [ "$type" = "wifi" ]; then
      signal=$(nmcli -t -f IN-USE,SIGNAL device wifi 2>/dev/null | grep '^*:' | cut -d: -f2)
      if [ -z "$signal" ]; then
        signal=100
      fi
      echo "{\"type\":\"wifi\", \"name\":\"$conn\", \"signal\":$signal, \"wifi_powered\":$wifi_powered}"
    elif [ "$type" = "ethernet" ]; then
      echo "{\"type\":\"ethernet\", \"name\":\"$conn\", \"signal\":100, \"wifi_powered\":$wifi_powered}"
    else
      echo "{\"type\":\"other\", \"name\":\"$conn\", \"signal\":100, \"wifi_powered\":$wifi_powered}"
    fi
  else
    echo "{\"type\":\"disconnected\", \"name\":\"\", \"signal\":0, \"wifi_powered\":$wifi_powered}"
  fi
}

while true; do
  get_net
  sleep 5
done
