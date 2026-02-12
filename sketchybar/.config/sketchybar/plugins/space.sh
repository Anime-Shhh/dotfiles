#!/bin/sh

# The $SELECTED variable is available for space components and indicates if
# the space invoking this script (with name: $NAME) is currently selected:
# https://felixkratz.github.io/SketchyBar/config/components#space----associate-mission-control-spaces-with-an-item

CACHE_DIR="$HOME/.cache/sketchybar"
DOMINANT_FILE="$CACHE_DIR/dominant_color"
BACKGROUND_FILE="$CACHE_DIR/background_color"

source "$CONFIG_DIR/colors.sh" # Loads all defined colors

# Use dynamic colors if available, otherwise fall back to static colors
DYNAMIC_DOMINANT=$(cat "$DOMINANT_FILE" 2>/dev/null)
DYNAMIC_BACKGROUND=$(cat "$BACKGROUND_FILE" 2>/dev/null)

FG_COLOR="${DYNAMIC_DOMINANT:-$ACCENT_COLOR}"
BG_COLOR="${DYNAMIC_BACKGROUND:-$BAR_COLOR}"

if [ $SELECTED = true ]; then
  sketchybar --set $NAME background.drawing=on \
    background.color=$FG_COLOR \
    label.color=$BG_COLOR \
    icon.color=$BG_COLOR
else
  sketchybar --set $NAME background.drawing=off \
    label.color=$FG_COLOR \
    icon.color=$FG_COLOR
fi
