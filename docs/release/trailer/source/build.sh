#!/bin/sh
# One command: the Brick Toy trailer for Tock's Wind-Up Workshop.
#   sh films/tock-trailer/build.sh        score, events, mix, picture (24 fps), master at -14 LUFS, poster
# Needs the core and music tiers (setup.sh deps music), the HDRI pack (tools/fetch.sh hdri) and VCSL (tools/fetch.sh instruments vcsl).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
LIB=${LIB:-$(cd "$HERE/../.." && pwd)}
export LIB
[ -f "$LIB/core/render/video.mjs" ] || { echo "set LIB to the library folder"; exit 1; }
PY="$LIB/.venv/bin/python"
NAME=tocks-wind-up-workshop-trailer
FPS=24
cd "$LIB"
mkdir -p "$HERE/out"
"$PY" "$HERE/score.py"
node core/render/events.mjs "$HERE"
"$PY" "$HERE/mix.py"
# One worker by default: with two on integrated graphics, one worker once lost the ruler's texture (it rendered dark).
node core/render/video.mjs "$HERE" --fps $FPS --workers ${WORKERS:-1} --out "$HERE/out/video.mp4"
sh core/render/mux.sh "$HERE/out/video.mp4" "$HERE/out/mix.wav" "$HERE/$NAME.mp4" $FPS 2
ffmpeg -v error -y -ss 9.70 -i "$HERE/$NAME.mp4" -frames:v 1 -q:v 2 "$HERE/poster.jpg"
echo "done: $HERE/$NAME.mp4"
