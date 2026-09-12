#!/usr/bin/env python3
import os
import json
import subprocess

data = {
    "battery": {"percent": 0, "state": "Unknown", "exists": False},
    "brightness": {"percent": 0, "exists": False},
    "power_profile": {"current": "balanced", "exists": False}
}

# 1. Battery
try:
    bats = [b for b in os.listdir("/sys/class/power_supply") if b.startswith("BAT") or b.startswith("BIF")]
    if bats:
        bat = bats[0]
        with open(f"/sys/class/power_supply/{bat}/capacity") as f:
            data["battery"]["percent"] = int(f.read().strip())
        with open(f"/sys/class/power_supply/{bat}/status") as f:
            data["battery"]["state"] = f.read().strip()
        data["battery"]["exists"] = True
except Exception:
    pass

# 2. Brightness
try:
    bctl = subprocess.run(["brightnessctl", "i", "-m"], capture_output=True, text=True)
    if bctl.returncode == 0 and bctl.stdout.strip():
        parts = bctl.stdout.strip().split("\n")[0].split(",")
        if len(parts) >= 4:
            pct = parts[3].replace("%", "")
            data["brightness"]["percent"] = int(pct)
            data["brightness"]["exists"] = True
except Exception:
    pass

# 3. Power profile
try:
    ppd = subprocess.run(["powerprofilesctl", "get"], capture_output=True, text=True)
    if ppd.returncode == 0:
        data["power_profile"]["current"] = ppd.stdout.strip()
        data["power_profile"]["exists"] = True
except Exception:
    pass

print(json.dumps(data))
