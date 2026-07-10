#!/usr/bin/env bash

prev_user=0
prev_nice=0
prev_system=0
prev_idle=0
prev_iowait=0
prev_irq=0
prev_softirq=0
prev_steal=0

while true; do
  # Read /proc/stat
  read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
  
  # Calculate differences
  prev_total=$((prev_user + prev_nice + prev_system + prev_idle + prev_iowait + prev_irq + prev_softirq + prev_steal))
  total=$((user + nice + system + idle + iowait + irq + softirq + steal))
  
  diff_total=$((total - prev_total))
  diff_idle=$((idle - prev_idle))
  
  if [ $diff_total -gt 0 ]; then
    cpu_usage=$(( (diff_total - diff_idle) * 100 / diff_total ))
  else
    cpu_usage=0
  fi
  
  prev_user=$user
  prev_nice=$nice
  prev_system=$system
  prev_idle=$idle
  prev_iowait=$iowait
  prev_irq=$irq
  prev_softirq=$softirq
  prev_steal=$steal
  
  # RAM usage
  ram_usage=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
  
  echo "{\"cpu\": $cpu_usage, \"ram\": $ram_usage}"
  sleep 3
done
