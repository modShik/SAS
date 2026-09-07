#!/bin/bash
# Rasterise assets/wallpaper.svg into a destination directory.
#
#   gen-wallpaper.sh <dest-dir> [width] [height]
#
# Replaces the original approach of wget-ing stock photos from Unsplash at
# build time, which made builds non-reproducible, network-dependent and of
# uncertain licensing.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
. "$REPO_ROOT/scripts/lib/common.sh"

DEST="${1:?usage: gen-wallpaper.sh <dest-dir> [width] [height]}"
WIDTH="${2:-1920}"
HEIGHT="${3:-1080}"
SRC="$REPO_ROOT/assets/wallpaper.svg"

[ -f "$SRC" ] || die "wallpaper source not found: $SRC"
mkdir -p "$DEST"
OUT="$DEST/default.png"

if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w "$WIDTH" -h "$HEIGHT" -o "$OUT" "$SRC"
elif command -v convert >/dev/null 2>&1; then
    # ImageMagick's built-in SVG renderer drops gradients and mangles
    # letter-spaced text, so don't feed it the SVG. Approximate the design
    # with native primitives instead. The container ships librsvg2-bin, so
    # this path only matters for --native builds on a host without it.
    warn "rsvg-convert not found; drawing a simplified wallpaper with ImageMagick"
    convert -size "${WIDTH}x${HEIGHT}" \
            gradient:'#203a43'-'#0f2027' \
            -gravity center \
            -fill '#ffffff' -pointsize 150 -annotate +0-40 'SAS OS' \
            -fill '#9fd4e0' -pointsize 30 -annotate +0+70 'DEVELOPMENT ENVIRONMENT' \
            "$OUT"
else
    die "need rsvg-convert or ImageMagick's convert to render the wallpaper"
fi

chmod 0644 "$OUT"
ok "wallpaper rendered -> $OUT (${WIDTH}x${HEIGHT})"
