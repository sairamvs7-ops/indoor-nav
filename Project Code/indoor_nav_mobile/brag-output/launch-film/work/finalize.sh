#!/usr/bin/env bash
# Poster frame (baked in as frame 0) and the vertical cut-down.
set -e
cd "$(dirname "$0")/.."
F=via-launch-film.mp4
POSTER_T=35.0
# 1) poster: the full-frame real route with its headline
ffmpeg -loglevel error -y -ss $POSTER_T -i $F -frames:v 1 -q:v 2 brag.jpg
# 2) bake the poster as frame 0 (replaces that frame; length unchanged)
ffmpeg -loglevel error -y -i $F -i brag.jpg -filter_complex "[0:v][1:v]overlay=enable='lt(n\,1)'[v]" -map "[v]" -map 0:a \
  -c:v libx264 -crf 16 -preset slow -pix_fmt yuv420p -c:a copy -movflags +faststart work/with_poster.mp4
mv work/with_poster.mp4 $F
# 3) vertical 1080x1920: the film scaled to full width over a blurred brand-sand fill
ffmpeg -loglevel error -y -i $F -filter_complex \
  "[0:v]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,boxblur=40:2,eq=brightness=0.04[bg];[0:v]scale=1080:-2[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2[v]" \
  -map "[v]" -map 0:a -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p -c:a copy -movflags +faststart via-launch-film-vertical.mp4
for f in $F via-launch-film-vertical.mp4; do ffprobe -v error -show_entries format=duration:stream=width,height -of compact $f; done
echo finalized
