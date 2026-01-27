#!/bin/bash

SPOTIFY_COLORS="$HOME/.config/sketchybar/scripts/spotify_colors"
COLOR_OUTPUT="$("$SPOTIFY_COLORS")"

DOMINANT=$(echo "$COLOR_OUTPUT" | grep "^DOMINANT=" | cut -d= -f2)
BACKGROUND=$(echo "$COLOR_OUTPUT" | grep "^BACKGROUND=" | cut -d= -f2)

[ -z "$DOMINANT" ] && exit 0
[ -z "$BACKGROUND" ] && exit 0

# Apply colors to specific items (update these IDs)
sketchybar \
  --set volume background.color="$BACKGROUND" label.color="$DOMINANT" icon.color="$DOMINANT" \
  --set battery background.color="$BACKGROUND" label.color="$DOMINANT" icon.color="$DOMINANT" \
  --set calendar background.color="$BACKGROUND" label.color="$DOMINANT" icon.color="$DOMINANT" \
  --set front_app background.color="$BACKGROUND" label.color="$DOMINANT" icon.color="$DOMINANT" \
  --set spaces background.color="$BACKGROUND" label.color="$DOMINANT" icon.color="$DOMINANT"

sketchybar --add item spotify_color right \
  --set spotify_color \
  drawing=off \
  script="$CONFIG_DIR/plugins/spotify_color.sh" \
  update_freq=2
