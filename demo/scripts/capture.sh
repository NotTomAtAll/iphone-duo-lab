#!/bin/zsh
# Capture DuoLab on the iPhone Duo simulator.
#
#   scripts/capture.sh                          # home, all topic pages, playbook, device; open + closed
#   scripts/capture.sh book                     # one pose (open | book | closed)
#   TOPICS="grids media" scripts/capture.sh     # some topic pages
#   OPTIONS="grids/fixed-two media/sheet" scripts/capture.sh open   # option previews too
#   MEASURE=1 scripts/capture.sh                # with the measure overlay
#
# Folding uses `rocketsim duo pose` (simctl has no pose verb).
# Screenshots: outer = --display=primary, inner = --display=primary-1.
set -euo pipefail

UDID=${UDID:-EA417F70-0BD4-4029-9752-7898AD712EB6}
BUNDLE=com.example.duolab
OUT=${OUT:-${0:A:h}/../captures}
TOPICS=(${=TOPICS:-tabbar toolbars listdetail grids reading media overlays sheets hinge antipatterns})
OPTIONS=(${=OPTIONS:-})
POSES=(${@:-open closed})
MEASURE=${MEASURE:-0}
WAIT=${WAIT:-6}
mkdir -p "$OUT"

shot() { # pose name
  local display=primary
  [[ $1 == closed ]] || display=primary-1
  xcrun simctl io "$UDID" screenshot --display=$display "$OUT/$2-$1.png" >/dev/null 2>&1
  echo "  $OUT/$2-$1.png"
}

launch() { xcrun simctl launch --terminate-running-process "$UDID" $BUNDLE -measure $MEASURE "$@" >/dev/null; }

for pose in $POSES; do
  rocketsim duo pose "$pose" --udid "$UDID" >/dev/null
  sleep 2
  echo "pose $pose"
  launch; sleep $WAIT; shot $pose 00-home
  launch -tab playbook; sleep 3; shot $pose 00-playbook
  launch -tab device; sleep 3; shot $pose 00-device
  i=1
  for topic in $TOPICS; do
    launch -topic $topic; sleep $WAIT
    shot $pose "$(printf %02d $i)-$topic"
    i=$((i + 1))
  done
  for target in $OPTIONS; do
    launch -topic ${target%%/*} -option ${target##*/}; sleep 3
    shot $pose "opt-${target%%/*}-${target##*/}"
  done
done
