#!/bin/zsh
# Produce the README images: each topic's recommended option on the open and the folded
# display, composed side by side, plus the home and device screens.
#
#   demo/scripts/readme-shots.sh            # all
#   SHOTS="tabbar media" demo/scripts/readme-shots.sh
#
# Output: docs/images/<name>.png (composed, 1600 px wide) and docs/images/raw/.
# Needs the app installed on the Duo sim, `rocketsim duo pose`, and ImageMagick (`magick`).
set -euo pipefail

UDID=${UDID:-EA417F70-0BD4-4029-9752-7898AD712EB6}
BUNDLE=com.example.duolab
ROOT=${0:A:h}/../..
OUT=$ROOT/docs/images
RAW=$OUT/raw
FONT=${FONT:-/System/Library/Fonts/Supplemental/Arial.ttf}
WAIT=${WAIT:-5}
mkdir -p "$RAW"

# name | launch args
typeset -A SHOT
SHOT=(
  home          ""
  device        "-tab device"
  tabbar        "-topic tabbar -option native"
  tabbar-sidebar "-topic tabbar -option sidebar"
  toolbars      "-topic toolbars -option system"
  listdetail    "-topic listdetail -option split"
  grids         "-topic grids -option adaptive-even"
  reading       "-topic reading -option column"
  media         "-topic media -option arrangement-split"
  overlays      "-topic overlays -option fold-aware"
  sheets        "-topic sheets -option sheet-form -duolab.present 1"
  hinge         "-topic hinge -option book"
  pitfalls      "-topic antipatterns -option screen-size"
  continuity    "-topic continuity -option above"
  laptop        "-topic laptop -option overlay -knob.simulatedPose laptop"
  motion        "-topic motion -option mode"
  toasts        "-topic toasts -option pill -duolab.pinToast 1"
  twopanes      "-topic twopanes -option split-drag"
  keyboard      "-topic keyboard -option composer-in-pane -duolab.focusComposer 1"
  transitions   "-topic transitions -option zoom"
  topic-page    "-topic grids"
)
# Per-pose overrides (the open display shows the split with a topic selected).
typeset -A SHOT_OPEN
SHOT_OPEN=( home "-topic grids" )
ORDER=(home topic-page tabbar tabbar-sidebar toolbars listdetail grids reading media overlays sheets hinge pitfalls continuity laptop motion toasts twopanes keyboard transitions device)
NAMES=(${=SHOTS:-$ORDER})

launch() { xcrun simctl launch --terminate-running-process "$UDID" $BUNDLE -measure 0 -duolab.hideBar 1 ${=1} >/dev/null; sleep $WAIT; }

for pose in open closed; do
  rocketsim duo pose $pose --udid "$UDID" >/dev/null; sleep 2
  display=primary-1; [[ $pose == closed ]] && display=primary
  for name in $NAMES; do
    args="${SHOT[$name]}"
    [[ $pose == open && -n "${SHOT_OPEN[$name]:-}" ]] && args="${SHOT_OPEN[$name]}"
    launch "$args"
    xcrun simctl io "$UDID" screenshot --display=$display "$RAW/$name-$pose.png" >/dev/null 2>&1
    echo "  $name-$pose"
  done
done

# Compose: open (951×669 @3x) left, closed (466×678 @3x) right, same height, on a neutral background.
for name in $NAMES; do
  magick "$RAW/$name-open.png" -resize x1200 \
         \( "$RAW/$name-closed.png" -resize x1200 \) \
         -background '#e9e9ec' -splice 24x0+0+0 +append -gravity center -extent "%[fx:w+48]x%[fx:h+48]" \
         -resize 1600x "$OUT/$name.png"
  echo "composed $OUT/$name.png"
done
