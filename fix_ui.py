import re
import urllib.request
import os

qml_file = os.path.expanduser("~/dotfiles/quickshell/.config/quickshell/shell.qml")
with open(qml_file, "r") as f:
    content = f.read()

# 1. DND Top Bar issue
# Before: Icon { source: "icons/bell-slash.svg"; color: window.dndActive ? "#ff605c" : "#88ffffff"; size: 15; anchors.verticalCenter: parent.verticalCenter }
content = re.sub(
    r'Icon \{ source: "icons/bell-slash\.svg"; color: window\.dndActive \? "#ff605c" : "#88ffffff"; size: 15; anchors\.verticalCenter: parent\.verticalCenter \}',
    'Icon { source: "icons/bell-slash.svg"; color: "#ff605c"; size: 15; anchors.verticalCenter: parent.verticalCenter; visible: window.dndActive }',
    content
)

# 2. Clock icon alignment
# Before: Icon { source: "icons/clock.svg"; color: "#ffffff"; size: 13 }
content = re.sub(
    r'Icon \{ source: "icons/clock\.svg"; color: "#ffffff"; size: 13 \}',
    'Icon { source: "icons/clock.svg"; color: "#ffffff"; size: 13; anchors.verticalCenter: parent.verticalCenter }',
    content
)

# Also fix clockText alignment if needed
content = re.sub(
    r'(id: clockText\s*\n\s*color: "#ffffff"\s*\n\s*font\.pixelSize: 13\s*\n\s*font\.bold: true)',
    r'\1\n                    anchors.verticalCenter: parent.verticalCenter',
    content
)

# 3. Control hub buttons alignment
def fix_button(m):
    icon_content = m.group(1)
    text_content = m.group(2)
    return f'Row {{ anchors.centerIn: parent; spacing: 8; Icon {{ {icon_content}; anchors.verticalCenter: parent.verticalCenter }} Text {{ {text_content}; anchors.verticalCenter: parent.verticalCenter }} }}'

content = re.sub(r'Row \{ spacing: 8; Icon \{ (.*?) \} Text \{ (.*?) \} \}', fix_button, content)

with open(qml_file, "w") as f:
    f.write(content)

# Download an unfilled clock icon to replace the solid one
clock_url = "https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/svgs/regular/clock.svg"
req = urllib.request.Request(clock_url, headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req) as response:
    clock_svg = response.read().decode('utf-8')

# Ensure SVG fills container properly (remove hardcoded width/height, add viewBox if missing)
clock_svg = re.sub(r'width="\d+" height="\d+"', '', clock_svg)
with open(os.path.expanduser("~/dotfiles/quickshell/.config/quickshell/icons/clock.svg"), "w") as f:
    f.write(clock_svg)
