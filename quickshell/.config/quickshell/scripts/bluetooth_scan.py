#!/usr/bin/env python3
import subprocess
import json
import time
import sys
import signal

# Turn scan on initially by keeping an interactive bluetoothctl process alive
scan_proc = subprocess.Popen(["bluetoothctl"], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, text=True)
scan_proc.stdin.write("scan on\n")
scan_proc.stdin.flush()

def cleanup(signum, frame):
    # Turn scan off on exit
    try:
        scan_proc.stdin.write("scan off\n")
        scan_proc.stdin.flush()
    except Exception:
        pass
    scan_proc.terminate()
    scan_proc.wait()
    sys.exit(0)

# Register cleanup for termination signals
signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGINT, cleanup)

def get_devices():
    try:
        # DBus query to get all known/discovered bluetooth objects and their interfaces/properties
        res = subprocess.run(["busctl", "call", "org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects", "--json=short"], capture_output=True, text=True)
        if res.returncode != 0:
            return []
        data = json.loads(res.stdout)
        
        device_list = []
        for path, interfaces in data["data"][0].items():
            if "org.bluez.Device1" in interfaces:
                dev = interfaces["org.bluez.Device1"]
                
                # Extract address, name, paired and connected states from DBus variants
                mac = dev.get("Address", {}).get("data", "")
                name = dev.get("Alias", {}).get("data", "") or dev.get("Name", {}).get("data", "") or "Unknown Device"
                paired = dev.get("Paired", {}).get("data", False)
                connected = dev.get("Connected", {}).get("data", False)
                
                if not mac:
                    continue
                
                address_type = dev.get("AddressType", {}).get("data", "public")
                device_list.append({
                    "mac": mac,
                    "name": name,
                    "paired": paired,
                    "connected": connected,
                    "address_type": address_type
                })
        
        # De-duplicate by name (case-insensitive)
        by_name = {}
        for d in device_list:
            name_lower = d["name"].lower()
            if name_lower not in by_name:
                by_name[name_lower] = []
            by_name[name_lower].append(d)
        
        deduplicated = []
        for name_lower, dups in by_name.items():
            # Sort duplicates to put the best one first
            dups.sort(key=lambda x: (
                not x["connected"],
                not x["paired"],
                x["address_type"] != "public",
                x["mac"]
            ))
            best = dups[0]
            # Remove helper key before returning
            del best["address_type"]
            deduplicated.append(best)
            
        # Sort the final list: connected first, then paired, then by name
        deduplicated.sort(key=lambda x: (not x["connected"], not x["paired"], x["name"].lower()))
        return deduplicated
    except Exception as e:
        return []

try:
    last_json = ""
    while True:
        devices = get_devices()
        current_json = json.dumps(devices)
        if current_json != last_json:
            print(current_json)
            sys.stdout.flush()
            last_json = current_json
        time.sleep(1.0)
except KeyboardInterrupt:
    pass
finally:
    cleanup(None, None)
