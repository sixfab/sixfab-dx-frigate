#!/usr/bin/env bash
# Bird Species ID - interactive, re-runnable install. Run it ON the Raspberry Pi 5 after toolkit/install-frigate.sh.
# Adds the NABirds detector (555 species, one model) and your bird camera(s). No listener: species arrive on frigate/<camera>/<species>.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../toolkit/common.sh"

APP=bird-species-id
SCENE=outdoor_thermal

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
run cp "$HERE/model/nabirds-new/nabirds-new-model.dxnn" "$CONFIG_DIR/model_cache/nabirds-new-model.dxnn"
run cp "$HERE/model/nabirds-labelmap.txt" "$CONFIG_DIR/model_cache/nabirds-labelmap.txt"

add_species() {  # FRAGMENT_HOOK: every species of the labelmap into objects.track
    "$PYTHON" "$LIB/frigate_cfg.py" species "$1" "$HERE/model/nabirds-labelmap.txt" "$1.new" && mv "$1.new" "$1"
}
FRAGMENT_HOOK=add_species

echo "== 2/4: cameras =="
collect_cameras birdfeeder

echo "== 3/4: merging config.yaml =="
merge_fragment "$HERE/config/fragment.yaml" "$SCENE"
[ "${DRY_RUN:-0}" = "1" ] || "$PYTHON" "$LIB/frigate_cfg.py" disable-classifiers "$CONFIG_DIR/config.yaml"

echo "== 4/4: Frigate restart =="
restart_frigate

cat <<EOF

Install complete.

Verify:
  mosquitto_sub -h $(broker_for_listener) -t "frigate/+/+" -v
  docker exec $CONTAINER curl -s http://localhost:5000/api/stats

Re-run ./install.sh any time to add or remove cameras.
Frigate UI: https://$(hostname -I 2>/dev/null | awk '{print $1}'):8971
EOF
