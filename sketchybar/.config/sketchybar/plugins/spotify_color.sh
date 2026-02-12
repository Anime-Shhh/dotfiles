#!/bin/bash
#
# spotify_color.sh — Event-driven sketchybar color sync
#
# Triggered by:
#   spotify_change  — com.spotify.client.PlaybackStateChanged
#   system_woke     — macOS woke from sleep
#   forced          — initial sketchybar --update
#
# Behavior:
#   Spotify playing  → extract 2 distinct colors from album art
#   Otherwise        → extract 2 distinct colors from current wallpaper
#
# Colors are cached by track ID so they are never recomputed for the
# same song, and the script exits immediately if nothing changed.

CACHE_DIR="$HOME/.cache/sketchybar"
LAST_TRACK_FILE="$CACHE_DIR/last_track_id"
LAST_STATE_FILE="$CACHE_DIR/last_state"
ALBUM_CACHE="$CACHE_DIR/album_art.jpg"
WALLPAPER_CACHE="$CACHE_DIR/wallpaper.jpg"
COLOR_EXTRACTOR="$HOME/.config/sketchybar/scripts/color_extractor.py"

mkdir -p "$CACHE_DIR"

# -------------------------------------------------------------------
# Apply extracted colors to every sketchybar item
# -------------------------------------------------------------------
apply_colors() {
    local dominant="$1"
    local background="$2"

    [ -z "$dominant" ] && return
    [ -z "$background" ] && return

    # Persist current colors so other scripts (space.sh) can stay in sync
    echo "$dominant"   > "$CACHE_DIR/dominant_color"
    echo "$background" > "$CACHE_DIR/background_color"

    # Build one batched sketchybar call for all items
    local args=(
        --set volume         background.color="$background" label.color="$dominant" icon.color="$dominant"
        --set battery        background.color="$background" label.color="$dominant" icon.color="$dominant"
        --set calendar       background.color="$background" label.color="$dominant" icon.color="$dominant"
        --set front_app      background.color="$background" label.color="$dominant" icon.color="$dominant"
        --set space_separator icon.color="$dominant"
    )

    for sid in 1 2 3 4 5 6 7 8 9 10; do
        args+=(--set "space.$sid" background.color="$background" label.color="$dominant" icon.color="$dominant")
    done

    sketchybar "${args[@]}"
}

# -------------------------------------------------------------------
# Wallpaper color fallback
# -------------------------------------------------------------------
use_wallpaper_colors() {
    local last_state
    last_state=$(cat "$LAST_STATE_FILE" 2>/dev/null)

    # Already showing wallpaper colors — skip unless forced refresh
    if [[ "$last_state" == "wallpaper" && "$SENDER" != "system_woke" && "$SENDER" != "forced" ]]; then
        return
    fi

    # Get current desktop wallpaper path
    local wallpaper_path
    wallpaper_path=$(osascript -e 'tell application "System Events" to tell current desktop to get picture' 2>/dev/null)

    if [ -z "$wallpaper_path" ] || [ ! -f "$wallpaper_path" ]; then
        return
    fi

    # Convert to JPEG if the format is not natively supported (HEIC, etc.)
    local ext="${wallpaper_path##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    local img_path="$wallpaper_path"

    if [[ "$ext" != "jpg" && "$ext" != "jpeg" && "$ext" != "png" ]]; then
        sips -s format jpeg "$wallpaper_path" --out "$WALLPAPER_CACHE" >/dev/null 2>&1
        img_path="$WALLPAPER_CACHE"
    fi

    local color_output
    color_output=$(python3 "$COLOR_EXTRACTOR" "$img_path" 2>/dev/null)

    local dominant background
    dominant=$(echo "$color_output" | grep "^DOMINANT=" | cut -d= -f2)
    background=$(echo "$color_output" | grep "^BACKGROUND=" | cut -d= -f2)

    apply_colors "$dominant" "$background"

    echo "wallpaper" > "$LAST_STATE_FILE"
    rm -f "$LAST_TRACK_FILE"
}

# -------------------------------------------------------------------
# Main logic
# -------------------------------------------------------------------

# On system wake, clear caches so we re-evaluate from scratch
if [[ "$SENDER" == "system_woke" ]]; then
    rm -f "$LAST_TRACK_FILE" "$LAST_STATE_FILE"
fi

# Small delay to let Spotify settle after a state change
sleep 0.3

# Is Spotify even running?
SPOTIFY_RUNNING=$(osascript -e \
    'tell application "System Events" to (name of processes) contains "Spotify"' 2>/dev/null)

if [[ "$SPOTIFY_RUNNING" != "true" ]]; then
    use_wallpaper_colors
    exit 0
fi

# What is Spotify doing?
PLAYER_STATE=$(osascript -e \
    'tell application "Spotify" to player state as string' 2>/dev/null)

if [[ "$PLAYER_STATE" != "playing" ]]; then
    use_wallpaper_colors
    exit 0
fi

# --- Spotify is playing ---------------------------------------------------

TRACK_ID=$(osascript -e \
    'tell application "Spotify" to get id of current track' 2>/dev/null)
LAST_TRACK=$(cat "$LAST_TRACK_FILE" 2>/dev/null)

# Same track — nothing to do
if [[ "$TRACK_ID" == "$LAST_TRACK" ]]; then
    exit 0
fi

# Record new track
echo "$TRACK_ID" > "$LAST_TRACK_FILE"
echo "spotify"   > "$LAST_STATE_FILE"

# Download album art
ARTWORK_URL=$(osascript -e \
    'tell application "Spotify" to get artwork url of current track' 2>/dev/null)

if [ -z "$ARTWORK_URL" ]; then
    exit 0
fi

curl -s "$ARTWORK_URL" -o "$ALBUM_CACHE"

if [ ! -s "$ALBUM_CACHE" ]; then
    exit 0
fi

# Extract and apply
COLOR_OUTPUT=$(python3 "$COLOR_EXTRACTOR" "$ALBUM_CACHE" 2>/dev/null)

DOMINANT=$(echo "$COLOR_OUTPUT"  | grep "^DOMINANT="   | cut -d= -f2)
BACKGROUND=$(echo "$COLOR_OUTPUT" | grep "^BACKGROUND=" | cut -d= -f2)

apply_colors "$DOMINANT" "$BACKGROUND"
