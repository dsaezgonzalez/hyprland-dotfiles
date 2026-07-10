#!/usr/bin/env python3
import subprocess
import time
import sys
import base64

last_text = ""
while True:
    try:
        res = subprocess.run(["wl-paste", "-n", "--type", "text"], capture_output=True, text=True)
        if res.returncode == 0:
            text = res.stdout.rstrip('\r\n')
            if text != last_text:
                b64 = base64.b64encode(text.encode('utf-8')).decode('utf-8')
                print(b64)
                sys.stdout.flush()
                last_text = text
    except Exception:
        pass
    time.sleep(0.5)
