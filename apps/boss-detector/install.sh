#!/usr/bin/env bash
# Boss Detector - interactive, re-runnable install. Run it ON the Raspberry Pi 5
# after toolkit/install-frigate.sh. Adds the yolov8n COCO-80 model and your camera(s) to Frigate and
# installs a small MQTT listener that publishes boss_detector/alert on every person.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../toolkit/common.sh"

APP=boss-detector
SCENE=indoor_thermal

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
run cp "$HERE/model/yolov8n-ppu-coco80.dxnn" "$CONFIG_DIR/model_cache/yolov8n-ppu-coco80.dxnn"
run cp "$HERE/model/coco80-labelmap.txt" "$CONFIG_DIR/model_cache/coco80-labelmap.txt"

echo "== 2/4: cameras =="
collect_cameras cam

echo "== 3/4: merging config.yaml =="
merge_fragment "$HERE/config/fragment.yaml" "$SCENE"

echo "== 4/4: listener + Frigate restart =="
install_listener "$APP" "$HERE/automation/notify.py" "Boss Detector - Frigate MQTT person listener" "$SCENE"
restart_frigate

cat <<EOF

Install complete.

Verify:
  mosquitto_sub -h $(broker_for_listener) -t boss_detector/alert -v
  docker exec $CONTAINER curl -s http://localhost:5000/api/stats
  systemctl --user status $APP-automation.service --no-pager -n 30

Re-run ./install.sh any time to add or remove cameras.
Frigate UI: https://$(hostname -I 2>/dev/null | awk '{print $1}'):8971
EOF
