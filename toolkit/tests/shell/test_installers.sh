#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"
export PYTHON="${PYTHON:-python3}" SIXFAB_TEST=1 SIXFAB_NO_TTY=1 PATH="$HERE/fakebin:$PATH"
T="$(mktemp -d)"
export FAKE_CONFIG_DIR="$T/cfg" FAKE_LOG="$T/log" HOME="$T/home" ASSUME_YES=1
mkdir -p "$T/cfg" "$T/home" "$T/rel"
printf 'mqtt:\n  host: 10.1.1.1\nmodels: []\n' > "$T/cfg/config.yaml"
N=0

# stage_app <app>: copy toolkit+the app to a fresh dir (REPO), serve fake release assets, rewrite SHAs
stage_app() {
  N=$((N+1)); REPO="$T/repo$N"; mkdir -p "$REPO/apps"
  cp -r "$ROOT" "$REPO/toolkit"
  cp -r "$ROOT/../apps/$1" "$REPO/apps/$1"
  local tag; tag="$(sed -n 's/^# TAG: //p' "$REPO/apps/$1/models.txt")"
  mkdir -p "$T/rel/$tag"
  { echo "# TAG: $tag"
    grep -v -e '^#' -e '^$' "$REPO/apps/$1/models.txt" | while read -r n p s o; do
      printf 'fake-%s' "$n" > "$T/rel/$tag/$n"
      echo "$n  $p  $(sha256sum "$T/rel/$tag/$n" | cut -d' ' -f1)  $o"; done; } > "$REPO/apps/$1/models.txt.new"
  mv "$REPO/apps/$1/models.txt.new" "$REPO/apps/$1/models.txt"
}
export RELEASE_BASE_URL="file:///$(cygpath -m "$T" 2>/dev/null || echo "${T#/}")/rel"
cams() { "$PYTHON" "$ROOT/frigate_cfg.py" cameras "$T/cfg/config.yaml" "$1"; }

stage_app boss-detector
bash "$REPO/apps/boss-detector/install.sh" --rtsp-url "rtsp://u:p&w#x@h:554/s" --camera-name front --yes >"$T/out" 2>&1 \
  && pass "boss-detector installs" || { fail "boss-detector installs"; cat "$T/out"; }
assert_file "$REPO/apps/boss-detector/model/yolov8n-ppu-coco80.dxnn" "model downloaded"
assert_eq "front" "$(cams indoor_thermal)" "camera merged"
grep -qF 'rtsp://u:p&w#x@h:554/s' "$T/cfg/config.yaml" && pass "special chars in config" || fail "special chars in config"
assert_file "$HOME/.config/systemd/user/boss-detector-automation.service" "unit written"
grep -q 'enable --now boss-detector-automation.service' "$FAKE_LOG" && pass "systemd enabled" || fail "systemd enabled"
grep -q 'docker restart frigate' "$FAKE_LOG" && pass "frigate restarted" || fail "frigate restarted"

bash "$REPO/apps/boss-detector/install.sh" --rtsp-url rtsp://h/2 --camera-name back --yes >/dev/null 2>&1
assert_eq "front
back" "$(cams indoor_thermal)" "re-run adds camera"
assert_eq "1" "$(grep -c 'yolov8n-ppu-coco80.dxnn' "$T/cfg/config.yaml")" "model entry not duplicated"
assert_eq "front
back" "$(cat "$HOME/sixfab-apps/boss-detector/cameras.txt")" "cameras.txt has both"

printf 'models:\n  - scene: indoor_thermal\n    path: /config/model_cache/other.dxnn\n' > "$T/cfg/config.yaml"
cp "$T/cfg/config.yaml" "$T/before"
assert_fails "refuses taken scene" bash "$REPO/apps/boss-detector/install.sh" --rtsp-url rtsp://h/3 --yes
assert_eq "$(cat "$T/before")" "$(cat "$T/cfg/config.yaml")" "config untouched on refusal"

for spec in "porch-pirate:indoor" "squirrel-sprinkler:outdoor" "smart-doorbell:all" "bird-species-id:outdoor_thermal"; do
  app="${spec%%:*}"; scene="${spec##*:}"
  printf 'mqtt:
  host: 10.1.1.1
' > "$T/cfg/config.yaml"
  stage_app "$app"
  bash "$REPO/apps/$app/install.sh" --rtsp-url rtsp://h/cam --camera-name cam_a --yes >"$T/out" 2>&1     && pass "$app installs" || { fail "$app installs"; cat "$T/out"; }
  assert_eq "cam_a" "$(cams "$scene")" "$app camera in scene $scene"
done
assert_file "$HOME/sixfab-apps/porch-pirate/cameras.txt" "porch listener installed"
assert_file "$HOME/sixfab-apps/squirrel-sprinkler/cameras.txt" "squirrel listener installed"
assert_no_file "$HOME/sixfab-apps/smart-doorbell" "doorbell has no listener"

printf 'classification:
  bird:
    enabled: true
' > "$T/cfg/config.yaml"
stage_app bird-species-id
printf 'Yellow Warbler
Blue Jay
' > "$REPO/apps/bird-species-id/model/nabirds-labelmap.txt"
bash "$REPO/apps/bird-species-id/install.sh" --rtsp-url rtsp://h/bird --camera-name feeder --yes >/dev/null 2>&1
grep -q 'Blue Jay' "$T/cfg/config.yaml" && pass "bird species in track list" || fail "bird species in track list"
grep -A1 'bird:' "$T/cfg/config.yaml" | grep -q 'enabled: false' && pass "old classifier disabled" || fail "old classifier disabled"

N_BAK_BEFORE="$(ls "$T/cfg" | grep -c 'bak' || true)"
printf 'mqtt:
  host: 10.1.1.1
models: []
' > "$T/cfg/config.yaml"
cp "$T/cfg/config.yaml" "$T/dry-before"
stage_app boss-detector
HOME="$T/home-dry" bash "$REPO/apps/boss-detector/install.sh" --rtsp-url rtsp://h/d --camera-name dry --yes --dry-run >"$T/out" 2>&1   && pass "dry run exits 0" || { fail "dry run exits 0"; cat "$T/out"; }
assert_eq "$(cat "$T/dry-before")" "$(cat "$T/cfg/config.yaml")" "dry run leaves config.yaml alone"
assert_no_file "$T/home-dry/sixfab-apps" "dry run installs no listener"
ls "$T/cfg"/config.yaml.bak-*dry* >/dev/null 2>&1; n_bak="$(ls "$T/cfg" | grep -c 'bak' || true)"
assert_eq "$N_BAK_BEFORE" "$n_bak" "dry run makes no backup"

finish
