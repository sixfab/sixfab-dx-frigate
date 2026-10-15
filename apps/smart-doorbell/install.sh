#!/usr/bin/env bash
# Smart Doorbell - interactive, re-runnable install. Run it ON the Raspberry Pi 5 after toolkit/install-frigate.sh.
# Adds person detection on the NPU, Frigate face recognition and your door camera(s). There is no listener.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../toolkit/common.sh"

APP=smart-doorbell
SCENE=all

parse_flags "$@"
discover_frigate

camera_menu "$SCENE" "$APP"
case "$MODE" in
    quit) exit 0 ;;
    remove) remove_camera_flow "$SCENE" "$APP"; exit 0 ;;
esac

echo "== 1/4: model (from release $(models_tag "$HERE/models.txt")) =="
fetch_assets "$HERE" 0
mkdir -p "$CONFIG_DIR/model_cache"
run cp "$HERE/model/yolov8-n_640x640_ppu.dxnn" "$CONFIG_DIR/model_cache/yolov8-n_640x640_ppu.dxnn"
run cp "$HERE/model/coco80-labelmap.txt" "$CONFIG_DIR/model_cache/coco80-labelmap.txt"

echo "== 2/4: cameras =="
collect_cameras frontdoor

echo "== 3/4: merging config.yaml =="
merge_fragment "$HERE/config/fragment.yaml" "$SCENE"

echo "== 4/4: Frigate restart =="
restart_frigate

cat <<EOF

Install complete.

Verify:
  docker exec $CONTAINER curl -s http://localhost:5000/api/stats
  # look for cameras.<name>.detection_fps > 0 and embeddings.face_recognition_speed
Enroll faces (the nav item only shows in a desktop browser, use the URL):
  https://$(hostname -I 2>/dev/null | awk '{print $1}'):8971/faces

Re-run ./install.sh any time to add or remove cameras.
Frigate UI: https://$(hostname -I 2>/dev/null | awk '{print $1}'):8971
EOF
