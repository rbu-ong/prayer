#!/bin/bash
set -e

TITLE="$1"
VERSE="$2"
PRAYER="$3"
DURATION="$4"

echo "=== Inputs ==="
echo "Title:    $TITLE"
echo "Verse:    $VERSE"
echo "Duration: $DURATION"

# Split verse into quote and reference on ' — ' or ' - '
VERSE_TEXT=$(echo "$VERSE" | sed 's/ [—–-][—–-]* .*//')
VERSE_REF=$(echo "$VERSE"  | grep -oP '(?<=[—–-] ).*' || echo '')

echo "Verse text: $VERSE_TEXT"
echo "Verse ref:  $VERSE_REF"

# Write each text element to a file — avoids ALL FFmpeg escaping issues
echo "$TITLE"      > /tmp/title.txt
echo "$VERSE_TEXT" > /tmp/verse_text.txt
echo "$VERSE_REF"  > /tmp/verse_ref.txt

# Wrap prayer at 30 chars per line
echo "$PRAYER" | fold -s -w 30 > /tmp/prayer.txt
echo "Prayer:"
cat /tmp/prayer.txt

FONT_SERIF="/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf"
FONT_SERIF_BOLD="/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
FONT_SERIF_ITALIC="/usr/share/fonts/truetype/dejavu/DejaVuSerif-Italic.ttf"
FONT_SANS="/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"

FADE_OUT=$((DURATION - 2))

# Build filter — all text via textfile= to avoid special char escaping
printf '%s' \
  "[1:a]volume=2.5,afade=t=in:st=0:d=1,afade=t=out:st=${FADE_OUT}:d=2[voice];" \
  "[2:a]volume=1.0[music];" \
  "[music][voice]amix=inputs=2:duration=first[audio];" \
  "[0:v]" \
  "drawtext=text='Daily Prayer':fontfile=${FONT_SANS}:fontsize=42:fontcolor=0xFFDC64@0.75:x=(w-text_w)/2:y=80:shadowcolor=black:shadowx=2:shadowy=2," \
  "drawtext=textfile=/tmp/title.txt:fontfile=${FONT_SERIF_BOLD}:fontsize=64:fontcolor=white@1.0:x=(w-text_w)/2:y=155:shadowcolor=black:shadowx=3:shadowy=3," \
  "drawtext=textfile=/tmp/prayer.txt:fontfile=${FONT_SERIF}:fontsize=46:fontcolor=white@0.95:x=(w-text_w)/2:y=370:line_spacing=14:shadowcolor=black:shadowx=2:shadowy=2," \
  "drawtext=textfile=/tmp/verse_text.txt:fontfile=${FONT_SERIF_ITALIC}:fontsize=36:fontcolor=0xFFDC64@0.90:x=(w-text_w)/2:y=1700:shadowcolor=black:shadowx=2:shadowy=2," \
  "drawtext=textfile=/tmp/verse_ref.txt:fontfile=${FONT_SANS}:fontsize=32:fontcolor=0xFFDC64@0.65:x=(w-text_w)/2:y=1758:shadowcolor=black:shadowx=1:shadowy=1" \
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
