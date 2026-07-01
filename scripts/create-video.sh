#!/bin/bash
set -e

TITLE="$1"
VERSE="$2"
DURATION="$3"

echo "=== Inputs ==="
echo "Title:    $TITLE"
echo "Duration: $DURATION"

printf '%s' "$TITLE" > /tmp/title.txt

# Wrap long titles to 2 lines, splitting near the middle word boundary
python3 -c "
title = open('/tmp/title.txt').read().strip()
if len(title) > 20:
    words = title.split()
    half = len(title) // 2
    cum = 0
    split = len(words) // 2
    for i, w in enumerate(words[:-1]):
        cum += len(w) + 1
        if cum >= half:
            split = i + 1
            break
    line1 = ' '.join(words[:split])
    line2 = ' '.join(words[split:])
    open('/tmp/title.txt', 'w').write(line1 + '\n' + line2)
"

FONT_SERIF="/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf"
FONT_SERIF_BOLD="/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
FONT_SANS="/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"

FADE_OUT=$((DURATION - 2))

# Generate ASS caption file from word timestamps
python3 - << 'PYEOF'
import json, sys, os

with open('/tmp/timestamps.json') as f:
    words = json.load(f)

# Group into 2 words per caption
groups = []
i = 0
while i < len(words):
    group = words[i:i+2]
    text  = ' '.join(w['word'] for w in group)
    start = group[0]['start']
    end   = group[-1]['end']
    # Add a tiny gap so captions don't bleed into each other
    groups.append((start, end, text))
    i += 2

def fmt(t):
    h  = int(t // 3600)
    m  = int((t % 3600) // 60)
    s  = t % 60
    return f"{h}:{m:02d}:{s:05.2f}"

# ASS subtitle file
# Alignment 2 = bottom-center, MarginV pushes it up from the bottom
ass = """\
[Script Info]
ScriptType: v4.00+
PlayResX: 1080
PlayResY: 1920
WrapStyle: 0

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,95,&H00FFFFFF,&H000000FF,&H00000000,&H99000000,-1,0,0,0,100,100,3,0,1,6,3,2,60,60,420,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""

for start, end, text in groups:
    ass += f"Dialogue: 0,{fmt(start)},{fmt(end)},Default,,0,0,0,,{text}\n"

with open('/tmp/captions.ass', 'w', encoding='utf-8') as f:
    f.write(ass)

print(f"Generated {len(groups)} caption groups")
PYEOF

echo "=== Captions ==="
cat /tmp/captions.ass

# Video filter — header + title overlays, captions burned in via ASS
printf '%s' \
  "[1:a]volume=2.5,afade=t=in:st=0:d=1,afade=t=out:st=${FADE_OUT}:d=2[voice];" \
  "[2:a]volume=1.0[music];" \
  "[music][voice]amix=inputs=2:duration=first[audio];" \
  "[0:v]" \
  "drawtext=text='Daily Prayer':fontfile=${FONT_SANS}:fontsize=44:fontcolor=0xFFDC64@0.85:x=(w-text_w)/2:y=80:shadowcolor=black:shadowx=2:shadowy=2," \
  "drawtext=textfile=/tmp/title.txt:fontfile=${FONT_SERIF_BOLD}:fontsize=66:fontcolor=white@1.0:x=(w-text_w)/2:y=155:shadowcolor=black:shadowx=3:shadowy=3:line_spacing=10," \
  "ass=/tmp/captions.ass" \
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
