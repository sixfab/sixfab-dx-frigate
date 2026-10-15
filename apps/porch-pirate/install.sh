#!/usr/bin/env bash
# Porch Pirate - interactive, re-runnable install. Run it ON the Raspberry Pi 5 after toolkit/install-frigate.sh.
# Adds the package/person model and your porch camera(s) to Frigate and installs the theft-alert listener (MQTT topic porch_pirate/theft_alert).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../toolkit/common.sh"

APP=porch-pirate
SCENE=indoor

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
run cp "$HERE/model/people-and-cardboxes/people-and-cardboxes.dxnn" "$CONFIG_DIR/model_cache/people-and-cardboxes.dxnn"
run cp "$HERE/model/people-and-cardboxes/labelmap.txt" "$CONFIG_DIR/model_cache/people-and-cardboxes-labelmap.txt"

echo "== 2/4: cameras =="
collect_cameras porch

echo "== 3/4: merging config.yaml =="
merge_fragment "$HERE/config/fragment.yaml" "$SCENE"

echo "== 4/4: listener + Frigate restart =="
install_listener "$APP" "$HERE/automation/porch_watch.py" "Porch Pirate - Frigate MQTT porch watch listener" "$SCENE"
restart_frigate

cat <<EOF

Install complete.

Verify:
  mosquitto_sub -h $(broker_for_listener) -t porch_pirate/theft_alert -v
  systemctl --user status $APP-automation.service --no-pager -n 30
  docker exec $CONTAINER curl -s http://localhost:5000/api/stats

Zone: a generic rectangle (frontdoor_zone) was added. Redraw it in the Frigate UI
(camera > Zones) so it follows your own porch.

Re-run ./install.sh any time to add or remove cameras.
Frigate UI: https://$(hostname -I 2>/dev/null | awk '{print $1}'):8971
EOF
