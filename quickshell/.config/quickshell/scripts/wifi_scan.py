#!/usr/bin/env python3
import subprocess
import json
import sys

def scan_wifi():
    try:
        # Get list of saved wireless connections
        saved_ssids = set()
        try:
            conn_res = subprocess.run(
                ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"],
                capture_output=True,
                text=True,
                check=True
            )
            for line in conn_res.stdout.strip().split("\n"):
                if not line:
                    continue
                parts = line.split(":")
                if len(parts) >= 2 and parts[1] == "802-11-wireless":
                    # Unescape colons in connection names/SSIDs
                    saved_ssids.add(parts[0].replace("\\:", ":"))
        except Exception:
            pass

        # Run nmcli command to list wifi access points
        res = subprocess.run(
            ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,ACTIVE", "device", "wifi", "list"],
            capture_output=True,
            text=True,
            check=True
        )
        
        networks = {}
        for line in res.stdout.strip().split("\n"):
            if not line:
                continue
            parts = line.split(":")
            if len(parts) < 4:
                continue
            
            # The SSID is everything before signal
            active = parts[-1].lower() == "yes"
            security = parts[-2]
            signal_str = parts[-3]
            try:
                signal = int(signal_str)
            except ValueError:
                signal = 0
            
            ssid = ":".join(parts[:-3]).replace("\\:", ":")
            
            if not ssid:
                continue
            
            net_info = {
                "ssid": ssid,
                "signal": signal,
                "security": security,
                "active": active,
                "saved": ssid in saved_ssids
            }
            
            # Keep strongest signal for each SSID
            if ssid not in networks or signal > networks[ssid]["signal"] or active:
                networks[ssid] = net_info
                
        # Sort: active networks first, then by signal strength descending
        sorted_nets = sorted(
            networks.values(),
            key=lambda x: (1 if x["active"] else 0, x["signal"]),
            reverse=True
        )
        
        print(json.dumps(sorted_nets))
        
    except Exception as e:
        print(json.dumps([]))

if __name__ == "__main__":
    scan_wifi()
