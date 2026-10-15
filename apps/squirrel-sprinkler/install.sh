#!/usr/bin/env bash
# Squirrel Sprinkler - interactive, re-runnable install. Run it ON the Raspberry Pi 5 after toolkit/install-frigate.sh.
# Adds the squirrel detector and your garden camera(s) to Frigate and installs the MQTT trigger listener (topic squirrel_sprinkler/trigger). No valve is wired: the listener only logs and publishes.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../toolkit/common.sh"

APP=squirrel-sprinkler
SCENE=outdoor

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
run cp "$HERE/model/squirrel-detector-model.dxnn" "$CONFIG_DIR/model_cache/squirrel-detector-model.dxnn"
run cp "$HERE/model/squirrel-only-labelmap.txt" "$CONFIG_DIR/model_cache/squirrel-only-labelmap.txt"

echo "== 2/4: cameras =="
collect_cameras garden

echo "== 3/4: merging config.yaml =="
merge_fragment "$HERE/config/fragment.yaml" "$SCENE"

echo "== 4/4: listener + Frigate restart =="
install_listener "$APP" "$HERE/automation/sprinkler.py" "Squirrel Sprinkler - Frigate MQTT trigger listener" "$SCENE"
restart_frigate

cat <<EOF

Install complete.

Verify:
  mosquitto_sub -h $(broker_for_listener) -t squirrel_sprinkler/trigger -v
  systemctl --user status $APP-automation.service --no-pager -n 30
  docker exec $CONTAINER curl -s http://localhost:5000/api/stats

Re-run ./install.sh any time to add or remove cameras.
Frigate UI: https://$(hostname -I 2>/dev/null | awk '{print $1}'):8971
EOF
