#!/usr/bin/env bash
CACHE_DIR="$HOME/.cache/qs-themes"
WALLPAPER_DIR="$HOME/.local/share/wallpapers/"

mkdir -p "$CACHE_DIR"

find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" \) | while read -r img; do
    name=$(basename "$img")
    thumb="$CACHE_DIR/$name.thumb.jpg"
    
    if [[ ! -f "$thumb" ]]; then
        echo "Generating thumbnail for $name..."
        magick "$img" -resize 200x200^ -gravity center -extent 200x200 "$thumb"
    fi
done
