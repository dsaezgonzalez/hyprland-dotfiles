#!/usr/bin/env python3
import sys
import subprocess
import colorsys
import json
import re

def hex_to_rgb(hex_color):
    hex_color = hex_color.lstrip('#')
    return tuple(int(hex_color[i:i+2], 16) for i in (0, 2, 4))

def rgb_to_hex(rgb):
    return '#{:02x}{:02x}{:02x}'.format(int(rgb[0]), int(rgb[1]), int(rgb[2]))

def get_image_colors(image_path):
    cmd = ['magick', image_path, '-resize', '200x200', '-colors', '12', '-unique-colors', 'txt:-']
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error running magick: {e}", file=sys.stderr)
        sys.exit(1)

    colors = []
    for line in result.stdout.splitlines():
        match = re.search(r'#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b', line)
        if match:
            hex_color = match.group(0)[:7] # Ignore alpha if present
            colors.append(hex_color)
    return colors

def clamp(val, min_val=0.0, max_val=1.0):
    return max(min_val, min(max_val, val))

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 colour_extract.py <image_path>")
        sys.exit(1)
        
    image_path = sys.argv[1]
    raw_hex_colors = get_image_colors(image_path)
    
    if not raw_hex_colors:
        print("Could not extract colors from image.", file=sys.stderr)
        sys.exit(1)

    parsed_colors = []
    for hex_c in raw_hex_colors:
        r, g, b = hex_to_rgb(hex_c)
        h, l, s = colorsys.rgb_to_hls(r/255.0, g/255.0, b/255.0)
        parsed_colors.append({
            'hex': hex_c,
            'h': h,
            'l': l,
            's': s,
            'score': s * l
        })
        
    # Sort by lightness for bg/fg
    by_lightness = sorted(parsed_colors, key=lambda c: c['l'])
    background = by_lightness[0]
    foreground = by_lightness[-1]
    
    # Filter colors with acceptable lightness for accents
    valid_accents = [c for c in parsed_colors if c['l'] > 0.25]
    if not valid_accents:
        valid_accents = parsed_colors
        
    by_score = sorted(valid_accents, key=lambda c: c['score'], reverse=True)
    accent = by_score[0]
    
    if len(by_score) > 1:
        secondary_accent = by_score[1]
    else:
        secondary_accent = accent
        
    acc_h = accent['h']
    
    # Helper to generate a derived color
    def derive(hue_shift, l_factor=1.0, s_factor=0.8, base_l=0.5):
        h = (acc_h + hue_shift / 360.0) % 1.0
        s = clamp(accent['s'] * s_factor, 0.4, 0.9)
        l = clamp(base_l * l_factor, 0.3, 0.85)
        r, g, b = colorsys.hls_to_rgb(h, l, s)
        return rgb_to_hex((r*255, g*255, b*255))

    palette = {
        'color0': background['hex'],
        'color8': derive(0, base_l=background['l'], l_factor=1.5, s_factor=0.2), # Lightened bg
        'color7': derive(0, base_l=foreground['l'], l_factor=0.9, s_factor=0.1), # Darkened fg
        'color15': foreground['hex'],
        
        'color1': derive(-120),
        'color9': derive(-120, l_factor=1.2),
        
        'color2': derive(120),
        'color10': derive(120, l_factor=1.2),
        
        'color3': derive(60),
        'color11': derive(60, l_factor=1.2),
        
        'color4': derive(-60),
        'color12': derive(-60, l_factor=1.2),
        
        'color5': derive(-90),
        'color13': derive(-90, l_factor=1.2),
        
        'color6': derive(90),
        'color14': derive(90, l_factor=1.2),
    }
    
    output = {
        "wallpaper": image_path,
        "accent": accent['hex'],
        "secondary_accent": secondary_accent['hex'],
        "background": background['hex'],
        "foreground": foreground['hex'],
        "cursor": accent['hex'],
        "palette": palette
    }
    
    print(json.dumps(output, indent=2))

if __name__ == "__main__":
    main()
