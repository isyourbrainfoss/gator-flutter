#!/usr/bin/env bash
# Generate Android launcher icons from the GTK Gator SVG.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SVG="${GATOR_SVG:-$ROOT_DIR/../Gator/data/org.gator.Gator.svg}"
RES="$ROOT_DIR/android/app/src/main/res"

if [[ ! -f "$SVG" ]]; then
  echo "SVG not found: $SVG" >&2
  exit 1
fi

declare -A SIZES=(
  [mipmap-mdpi]=48
  [mipmap-hdpi]=72
  [mipmap-xhdpi]=96
  [mipmap-xxhdpi]=144
  [mipmap-xxxhdpi]=192
)

for folder in "${!SIZES[@]}"; do
  size="${SIZES[$folder]}"
  out="$RES/$folder/ic_launcher.png"
  echo "Generating $out (${size}x${size})"
  rsvg-convert -w "$size" -h "$size" "$SVG" -o "$out"
done

# Adaptive icon foreground (432px canvas, icon centered at 288px).
rsvg-convert -w 288 -h 288 "$SVG" -o /tmp/gator_fg.png
convert -size 432x432 xc:none /tmp/gator_fg.png -gravity center -composite /tmp/gator_fg_canvas.png
for folder in drawable drawable-xxxhdpi; do
  mkdir -p "$RES/$folder"
  cp /tmp/gator_fg_canvas.png "$RES/$folder/ic_launcher_foreground.png"
done

ANYDPI="$RES/mipmap-anydpi-v26"
mkdir -p "$ANYDPI"
cat > "$ANYDPI/ic_launcher.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
EOF

COLORS="$RES/values/colors.xml"
if [[ ! -f "$COLORS" ]]; then
  cat > "$COLORS" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#1C71D8</color>
</resources>
EOF
fi

echo "Icons generated."