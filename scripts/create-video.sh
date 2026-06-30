#!/bin/bash
set -e

TITLE="$1"
PRAYER="$3"
DURATION="$4"

echo "=== Inputs ==="
echo "Title:    $TITLE"
echo "Duration: $DURATION"

# Write text to files — avoids ALL FFmpeg escaping issues
printf '%s' "$TITLE"  > /tmp/title.txt
echo "$PRAYER" | fold -s -w 30 > /tmp/prayer.txt

echo "Title file:"
cat /tmp/title.txt
echo "Prayer lines: $(wc -l < /tmp/prayer.txt)"

FONT_SERIF="/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf"
FONT_SERIF_BOLD="/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
FONT_SANS="/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"

FADE_OUT=$((DURATION - 2))

# Video layout:
#   y=80   — "Daily Prayer" gold label
#   y=160  — Prayer title, white bold
#   y=310  — Prayer body text
printf '%s' \
  "[1:a]volume=2.5,afade=t=in:st=0:d=1,afade=t=out:st=${FADE_OUT}:d=2[voice];" \
  "[2:a]volume=1.0[music];" \
  "[music][voice]amix=inputs=2:duration=first[audio];" \
  "[0:v]" \
  "drawtext=text='Daily Prayer':fontfile=${FONT_SANS}:fontsize=44:fontcolor=0xFFDC64@0.85:x=(w-text_w)/2:y=80:shadowcolor=black:shadowx=2:shadowy=2," \
  "drawtext=textfile=/tmp/title.txt:fontfile=${FONT_SERIF_BOLD}:fontsize=66:fontcolor=white@1.0:x=(w-text_w)/2:y=160:shadowcolor=black:shadowx=3:shadowy=3," \
  "drawtext=textfile=/tmp/prayer.txt:fontfile=${FONT_SERIF}:fontsize=46:fontcolor=white@0.95:x=(w-text_w)/2:y=320:line_spacing=14:shadowcolor=black:shadowx=2:shadowy=2" \
  "[v]" \
  > /tmp/filter.txt

echo "=== Filter ==="
cat /tmp/filter.txt

ffmpeg \
  -i background.mp4 \
  -i prayer.mp3 \
  -i music.mp3 \
  -filter_complex_script /tmp/filter.txt \
  -map "[v]" -map "[audio]" \
  -t "$DURATION" \
  -c:v libx264 -preset fast -crf 20 \
  -c:a aac -b:a 192k \
  -movflags +faststart \
  output.mp4 -y

echo "=== Done ==="
echo "Video: $(du -sh output.mp4)"
