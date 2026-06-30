#!/bin/bash
set -e

TITLE="$1"
VERSE="$2"
PRAYER="$3"
DURATION="$4"

# Split verse into quote and reference
VERSE_TEXT=$(echo "$VERSE" | sed 's/ — .*//')
VERSE_REF=$(echo "$VERSE" | grep -o '— .*' || echo '')
VERSE_TEXT="${VERSE_TEXT:0:65}"
VERSE_REF="${VERSE_REF:0:35}"

# Wrap prayer at 30 chars per line for bigger font display
echo "$PRAYER" | fold -s -w 30 > /tmp/prayer.txt
echo "Prayer text:"
cat /tmp/prayer.txt

LINE_COUNT=$(wc -l < /tmp/prayer.txt)
echo "Total lines: $LINE_COUNT"

FONT_SERIF="/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf"
FONT_SERIF_BOLD="/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
FONT_SERIF_ITALIC="/usr/share/fonts/truetype/dejavu/DejaVuSerif-Italic.ttf"
FONT_SANS="/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"

FADE_OUT=$((DURATION - 2))

# Static prayer text centered — no scrolling, larger font
# Line height at fontsize 46 is ~60px, start at y=420, each line spaced 62px
# For ~17 lines that's 17*62=1054px ending at ~1474 — fits in 1920 height with verse at bottom
printf '%s' "[1:a]volume=2.5,afade=t=in:st=0:d=1,afade=t=out:st=${FADE_OUT}:d=2[voice];[2:a]volume=0.35[music];[music][voice]amix=inputs=2:duration=first[audio];[0:v]drawtext=text='✝':fontfile=${FONT_SERIF}:fontsize=100:fontcolor=0xFFDC64@0.95:x=(w-text_w)/2:y=55:shadowcolor=black:shadowx=3:shadowy=3,drawtext=text='Daily Prayer':fontfile=${FONT_SANS}:fontsize=42:fontcolor=0xFFDC64@0.75:x=(w-text_w)/2:y=180:shadowcolor=black:shadowx=2:shadowy=2,drawtext=text='${TITLE}':fontfile=${FONT_SERIF_BOLD}:fontsize=64:fontcolor=white@1.0:x=(w-text_w)/2:y=260:shadowcolor=black:shadowx=3:shadowy=3,drawtext=textfile=/tmp/prayer.txt:fontfile=${FONT_SERIF}:fontsize=46:fontcolor=white@0.95:x=(w-text_w)/2:y=420:line_spacing=14:shadowcolor=black:shadowx=2:shadowy=2,drawtext=text='${VERSE_TEXT}':fontfile=${FONT_SERIF_ITALIC}:fontsize=36:fontcolor=0xFFDC64@0.90:x=(w-text_w)/2:y=1720:shadowcolor=black:shadowx=2:shadowy=2,drawtext=text='${VERSE_REF}':fontfile=${FONT_SANS}:fontsize=32:fontcolor=0xFFDC64@0.65:x=(w-text_w)/2:y=1775:shadowcolor=black:shadowx=1:shadowy=1[v]" > /tmp/filter.txt

echo "Filter written"

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

echo "Video created: $(du -sh output.mp4)"
