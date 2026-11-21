#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
RES=android/app/src/main/res
for d in mdpi:48:108:24 hdpi:72:162:36 xhdpi:96:216:48 xxhdpi:144:324:72 xxxhdpi:192:432:96; do
  IFS=: read -r n s f t <<< "$d"
  mkdir -p "$RES/mipmap-$n" "$RES/drawable-$n"
  rsvg-convert -w "$s" -h "$s" branding/icon_full.svg -o "$RES/mipmap-$n/ic_launcher.png"
  rsvg-convert -w "$f" -h "$f" branding/icon_fg.svg -o "$RES/mipmap-$n/ic_launcher_foreground.png"
  rsvg-convert -w "$t" -h "$t" branding/icon_stat.svg -o "$RES/drawable-$n/ic_stat_finup.png"
done
mkdir -p "$RES/mipmap-anydpi-v26" "$RES/values" "$RES/drawable" "$RES/drawable-v21"
cat > "$RES/mipmap-anydpi-v26/ic_launcher.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
XML
cat > "$RES/values/ic_launcher_background.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources><color name="ic_launcher_background">#2D2A6E</color></resources>
XML
for dir in drawable drawable-v21; do
cat > "$RES/$dir/launch_background.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/black" />
    <item><bitmap android:gravity="center" android:src="@mipmap/ic_launcher" /></item>
</layer-list>
XML
done
echo "Icons generated."

# Run post-create hooks (gradle tweaks etc.)
for f in post_create/*.sh; do
  if [ -f "$f" ]; then bash "$f"; fi
done
