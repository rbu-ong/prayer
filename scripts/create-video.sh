#!/bin/bash
set -e

TITLE="$1"
VERSE="$2"
PRAYER="$3"
DURATION="$4"

# Split verse into quote and reference
VERSE_TEXT=$(echo "$VERSE" | sed 's/ — .*//')
VERSE_REF=$(echo "$VERSE" | grep -o '-- .*' || echo "$VERSE" | grep -o '— .*' || echo '')
VERSE_TEXT="${VERSE_TEXT:0:70}"
VERSE_REF="${VERSE_REF:0:40}"

# Write prayer text wrapped at 35 chars per line
echo "$PRAYER" | fold -s -w 35 > /tmp/prayer.txt
echo "Prayer lines:"
cat /tmp/prayer.txt

# Calculate scroll speed
SCROLL_DURATION=$((DURATION - 5))
LINE_COUNT=$(wc -l < /tmp/prayer.txt)
TOTAL_TEXT_H=$((LINE_COUNT * 55))
SCROLL_SPEED=$(echo "scale=4; $TOTAL_TEXT_H / $SCROLL_DURATION" | bc)
echo "Lines: $LINE_COUNT, Total height: ${TOTAL_TEXT_H}px, Speed: ${SCROLL_SPEED}px/s"

FONT_SERIF="/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf"
FONT_SERIF_BOLD="/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
FONT_SERIF_ITALIC="/usr/share/fonts/truetype/dejavu/DejaVuSerif-Italic.ttf"
FONT_SANS="/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"

FADE_OUT=$((DURATION - 2))

# Write filter script
cat > /tmp/filter.txt << 'EOF_MARKER'
PLACEHOLDER
EOF_MARKER

# Replace with actual filter (using printf to avoid heredoc YAML issues)
printf '%s' "[1:a]volume=2.5,afade=t=in:st=0:d=1,afade=t=out:st=${FADE_OUT}:d=2[voice];[2:a]volume=0.12[music];[music][voice]amix=inputs=2:duration=first[audio];[0:v]drawtext=text='✝':fontfile=${FONT_SERIF}:fontsize=100:fontcolor=0xFFDC64@0.95:x=(w-text_w)/2:y=60:shadowcolor=black:shadowx=3:shadowy=3,drawtext=text='Daily Prayer':fontfile=${FONT_SANS}:fontsize=40:fontcolor=0xFFDC64@0.70:x=(w-text_w)/2:y=185:shadowcolor=black:shadowx=2:shadowy=2,drawtext=text='${TITLE}':fontfile=${FONT_SERIF_BOLD}:fontsize=62:fontcolor=white@1.0:x=(w-text_w)/2:y=270:shadowcolor=black:shadowx=3:shadowy=3,drawtext=textfile=/tmp/prayer.txt:fontfile=${FONT_SERIF}:fontsize=38:fontcolor=white@0.92:x=(w-text_w)/2:y=460+((t-2)*${SCROLL_SPEED}*-1):shadowcolor=black:shadowx=2:shadowy=2:enable='gte(t\,2)',drawtext=text='${VERSE_TEXT}':fontfile=${FONT_SERIF_ITALIC}:fontsize=34:fontcolor=0xFFDC64@0.90:x=(w-text_w)/2:y=1720:shadowcolor=black:shadowx=2:shadowy=2,drawtext=text='${VERSE_REF}':fontfile=${FONT_SANS}:fontsize=30:fontcolor=0xFFDC64@0.65:x=(w-text_w)/2:y=1775:shadowcolor=black:shadowx=1:shadowy=1[v]" > /tmp/filter.txt

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
