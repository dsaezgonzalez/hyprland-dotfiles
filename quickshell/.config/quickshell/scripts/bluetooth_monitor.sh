#!/usr/bin/env bash

get_bt() {
  powered_status=$(bluetoothctl show 2>/dev/null | grep "Powered:" | awk '{print $2}')
  if [ "$powered_status" = "yes" ]; then
    powered="true"
  else
    powered="false"
  fi

  connected_devs=$(bluetoothctl devices Connected 2>/dev/null)
  if [ -n "$connected_devs" ]; then
    connected="true"
    device=$(echo "$connected_devs" | head -n1 | cut -d' ' -f3-)
  else
    connected="false"
    device=""
  fi

  echo "{\"powered\": $powered, \"connected\": $connected, \"device\": \"$device\"}"
}

while true; do
  get_bt
  sleep 4
done
