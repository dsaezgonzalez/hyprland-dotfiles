#!/usr/bin/env python3
import sys
import subprocess

if len(sys.argv) < 3:
    sys.exit(1)

action = sys.argv[1]
val = sys.argv[2]

if action == "brightness":
    subprocess.run(["brightnessctl", "s", f"{val}%"])
elif action == "profile":
    subprocess.run(["powerprofilesctl", "set", val])
