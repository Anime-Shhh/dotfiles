#!/usr/bin/env python3
"""
Extract 2 visually distinct dominant colors from an image for sketchybar.

Uses quantized color histograms with WCAG contrast ratio enforcement
to guarantee the two returned colors are always readable against each other.

Usage: python3 color_extractor.py <image_path>
Output:
  DOMINANT=0xFFrrggbb    (lighter color — for text/icons)
  BACKGROUND=0xFFrrggbb  (darker color — for backgrounds)
"""

import sys
from collections import Counter
from PIL import Image


# ---------------------------------------------------------------------------
# Color math helpers
# ---------------------------------------------------------------------------

def relative_luminance(r, g, b):
    """WCAG 2.0 relative luminance (0.0 – 1.0)."""
    def linearize(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)


def contrast_ratio(c1, c2):
    """WCAG contrast ratio (1.0 – 21.0) between two (r, g, b) tuples."""
    l1 = relative_luminance(*c1)
    l2 = relative_luminance(*c2)
    lighter = max(l1, l2)
    darker  = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)


def color_distance(c1, c2):
    """Redmean-weighted Euclidean distance — cheap perceptual proxy."""
    rmean = (c1[0] + c2[0]) / 2
    dr = c1[0] - c2[0]
    dg = c1[1] - c2[1]
    db = c1[2] - c2[2]
    return (
        (2 + rmean / 256) * dr ** 2
        + 4 * dg ** 2
        + (2 + (255 - rmean) / 256) * db ** 2
    ) ** 0.5


def brightness(r, g, b):
    """Perceived brightness (ITU-R BT.601)."""
    return 0.299 * r + 0.587 * g + 0.114 * b


def quantize(rgb, step=24):
    """Map an (r,g,b) tuple to the center of its quantization bucket."""
    return tuple(min(255, (c // step) * step + step // 2) for c in rgb)


# ---------------------------------------------------------------------------
# Core extraction
# ---------------------------------------------------------------------------

def extract_colors(image_path, min_contrast=3.0, min_distance=80):
    """
    Return (foreground_hex, background_hex) — two sketchybar 0xAARRGGBB strings.

    Algorithm
    ---------
    1. Resize + quantize the image into ~11^3 color buckets.
    2. Primary = most frequent bucket.
    3. Walk remaining buckets (by frequency) and accept the first one whose
       WCAG contrast ratio AND perceptual distance both exceed thresholds.
       This avoids picking "white + light-gray" or "black + dark-gray" —
       the pair will always be visually distinct.
    4. If nothing passes strict thresholds, try relaxed thresholds.
    5. Last resort: synthesize a high-contrast companion.
    6. The lighter color becomes DOMINANT (text/icons), the darker becomes
       BACKGROUND (item backgrounds), which is further darkened 25 % for a
       clean bar look.
    """
    img = Image.open(image_path).convert("RGB")
    img = img.resize((80, 80))

    quantized = [quantize(p) for p in img.getdata()]
    counts    = Counter(quantized)
    ranked    = counts.most_common()

    if not ranked:
        return "0xff888888", "0xff222222"

    primary = ranked[0][0]

    # --- strict pass ----------------------------------------------------------
    secondary = None
    for color, _ in ranked[1:]:
        if contrast_ratio(primary, color) >= min_contrast \
           and color_distance(primary, color) >= min_distance:
            secondary = color
            break

    # --- relaxed pass ---------------------------------------------------------
    if secondary is None:
        for color, _ in ranked[1:]:
            if contrast_ratio(primary, color) >= 2.0 \
               and color_distance(primary, color) >= min_distance * 0.5:
                secondary = color
                break

    # --- last resort: synthesize ----------------------------------------------
    if secondary is None:
        if brightness(*primary) > 127:
            secondary = (30, 30, 30)
        else:
            secondary = (230, 230, 230)

    # Lighter → foreground,  darker → background
    if brightness(*primary) >= brightness(*secondary):
        foreground, background = primary, secondary
    else:
        foreground, background = secondary, primary

    # Darken the background 25 % for a cleaner bar aesthetic
    background = tuple(max(0, int(c * 0.75)) for c in background)

    fg = f"0xff{foreground[0]:02x}{foreground[1]:02x}{foreground[2]:02x}"
    bg = f"0xff{background[0]:02x}{background[1]:02x}{background[2]:02x}"
    return fg, bg


# ---------------------------------------------------------------------------
# CLI entry
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 color_extractor.py <image_path>", file=sys.stderr)
        sys.exit(1)

    try:
        fg, bg = extract_colors(sys.argv[1])
        print(f"DOMINANT={fg}")
        print(f"BACKGROUND={bg}")
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
