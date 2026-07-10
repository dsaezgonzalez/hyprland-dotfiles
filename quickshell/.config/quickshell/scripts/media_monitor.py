#!/usr/bin/env python3
import subprocess
import json
import time
import sys

def get_media_info():
    try:
        status_proc = subprocess.run(["playerctl", "status"], capture_output=True, text=True)
        status = status_proc.stdout.strip()
        if not status:
            return {"status": "Stopped", "artist": "", "title": "", "player": ""}
        
        artist_proc = subprocess.run(["playerctl", "metadata", "artist"], capture_output=True, text=True)
        artist = artist_proc.stdout.strip()
        
        title_proc = subprocess.run(["playerctl", "metadata", "title"], capture_output=True, text=True)
        title = title_proc.stdout.strip()
        
        player_proc = subprocess.run(["playerctl", "metadata", "--format", "{{playerName}}"], capture_output=True, text=True)
        player = player_proc.stdout.strip()
        
        return {
            "status": status,
            "artist": artist,
            "title": title,
            "player": player
        }
    except Exception:
        return {"status": "Stopped", "artist": "", "title": "", "player": ""}

def main():
    # Initial print
    print(json.dumps(get_media_info()))
    sys.stdout.flush()
    
    while True:
        # Check if player is running
        has_player = subprocess.run(["playerctl", "status"], capture_output=True).returncode == 0
        if has_player:
            # Run playerctl metadata --follow
            cmd = ["playerctl", "metadata", "--format", "{{status}}::{{artist}}::{{title}}::{{playerName}}", "--follow"]
            try:
                proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
                while True:
                    line = proc.stdout.readline()
                    if not line:
                        break
                    parts = line.strip().split("::")
                    if len(parts) >= 4:
                        status, artist, title, player = parts[0], parts[1], parts[2], parts[3]
                        print(json.dumps({
                            "status": status,
                            "artist": artist,
                            "title": title,
                            "player": player
                        }))
                        sys.stdout.flush()
            except Exception:
                pass
        
        # If player exited or couldn't start
        print(json.dumps({"status": "Stopped", "artist": "", "title": "", "player": ""}))
        sys.stdout.flush()
        time.sleep(3)

if __name__ == "__main__":
    main()
