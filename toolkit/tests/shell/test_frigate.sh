#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"
export SIXFAB_VENV=/opt/test-venv PYTHON="${PYTHON:-python3}" SIXFAB_TEST=1 SIXFAB_NO_TTY=1 PATH="$HERE/fakebin:$PATH"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export FAKE_CONFIG_DIR="$T/cfg" FAKE_LOG="$T/log" HOME="$T/home"; mkdir -p "$T/cfg" "$T/home"
. "$ROOT/common.sh"

cat > "$T/cfg/config.yaml" <<'EOT'
mqtt:
  host: 10.1.1.1
EOT
cat > "$T/frag.yaml" <<'EOT'
models:
  - scene: outdoor
    path: /config/model_cache/m.dxnn
cameras:
  garden:
    ffmpeg:
      inputs:
        - path: rtsp://template/x
          roles: [detect]
    detect:
      enabled: true
      scene: outdoor
EOT

parse_flags --rtsp-url rtsp://h/1 --camera-name cam9 --broker 1.2.3.4 --yes --dry-run
assert_eq "rtsp://h/1|cam9|1.2.3.4|1|1" "$RTSP_URL|$CAMERA_NAME|$BROKER|$ASSUME_YES|$DRY_RUN" "parse_flags"
unset RTSP_URL CAMERA_NAME BROKER ASSUME_YES DRY_RUN

msg="$(FAKE_NO_CONTAINER=1 bash -c "PATH=$HERE/fakebin:\$PATH; . $ROOT/common.sh; discover_frigate" 2>&1)"
echo "$msg" | grep -q 'install-frigate.sh' && pass "missing Frigate points to install-frigate.sh" || fail "missing Frigate points to install-frigate.sh"

discover_frigate
assert_eq "$T/cfg" "$CONFIG_DIR" "discover_frigate finds config dir"

export ASK_FROM_STDIN=1
printf '2\ngarden1\nrtsp://h/a\ngarden2\nrtsp://h/b\n' | { collect_cameras garden 2>/dev/null; echo "${CAM_NAMES[*]}|${CAM_URLS[*]}" > "$T/out"; }
assert_eq "garden1 garden2|rtsp://h/a rtsp://h/b" "$(cat "$T/out")" "collect_cameras two cameras"

assert_fails "test_collect_cameras_rejects_bad_count" bash -c ". $ROOT/common.sh; export ASK_FROM_STDIN=1; echo 0 | collect_cameras c"
assert_fails "collect_cameras rejects non-rtsp" bash -c "PATH=$HERE/fakebin:\$PATH; . $ROOT/common.sh; export ASK_FROM_STDIN=1; printf '1\nc1\nhttp://x\n' | collect_cameras c"
assert_fails "collect_cameras rejects unreachable stream" bash -c "PATH=$HERE/fakebin:\$PATH; . $ROOT/common.sh; export ASK_FROM_STDIN=1; printf '1\nc1\nrtsp://bad-stream\n' | collect_cameras c"
unset ASK_FROM_STDIN
assert_fails "test_collect_cameras_without_tty_needs_url" bash -c "PATH=$HERE/fakebin:\$PATH; SIXFAB_NO_TTY=1; . $ROOT/common.sh; collect_cameras c </dev/null"

CAM_NAMES=(garden1 garden2); CAM_URLS=("rtsp://u:p&w#x@h/a" rtsp://h/b)
merge_fragment "$T/frag.yaml" outdoor
ls "$T/cfg"/config.yaml.bak-* >/dev/null 2>&1 && pass "backup created" || fail "backup created"
assert_eq "garden1
garden2" "$("$PYTHON" "$LIB/frigate_cfg.py" cameras "$T/cfg/config.yaml" outdoor)" "test_merge_into_empty_config cameras merged"
grep -qF 'rtsp://u:p&w#x@h/a' "$T/cfg/config.yaml" && pass "special chars survive merge" || fail "special chars survive merge"
grep -q '10.1.1.1' "$T/cfg/config.yaml" && pass "mqtt host preserved" || fail "mqtt host preserved"

cat > "$T/frag2.yaml" <<'EOT'
models:
  - scene: outdoor
    path: /config/model_cache/OTHER.dxnn
cameras:
  z: {ffmpeg: {inputs: [{path: rtsp://t}]}, detect: {scene: outdoor}}
EOT
cp "$T/cfg/config.yaml" "$T/before.yaml"
assert_fails "merge refuses taken scene" merge_fragment "$T/frag2.yaml" outdoor
assert_eq "$(cat "$T/before.yaml")" "$(cat "$T/cfg/config.yaml")" "config untouched after refusal"

# camera naming on re-run (config already has garden1, garden2 in scene outdoor)
export CONFIG_DIR SCENE=outdoor
cc() {  # cc <stdin-text>: run collect_cameras garden in a fresh shell, print names or the error
  printf "$1" | bash -c "PATH=$HERE/fakebin:\$PATH; . $ROOT/common.sh; export ASK_FROM_STDIN=1; collect_cameras garden 2>/dev/null; echo \"\${CAM_NAMES[*]}\"" 2>&1
}
cc_err() { printf "$1" | bash -c "PATH=$HERE/fakebin:\$PATH; . $ROOT/common.sh; export ASK_FROM_STDIN=1; collect_cameras garden" 2>&1; }
assert_eq "garden3" "$(cc '1\n\nrtsp://h/z\n')" "default camera name is the next free one"
assert_eq "garden1" "$(cc '1\ngarden1\ny\nrtsp://h/z\n')" "existing name kept when replace confirmed"
cc_err '1\ngarden1\nn\nrtsp://h/z\n' | grep -q 'already exists' && pass "existing name refused when replace declined" || fail "existing name refused when replace declined"
cc_err '2\ng9\nrtsp://a\ng9\nrtsp://b\n' | grep -q 'more than once' && pass "duplicate names in one run refused" || fail "duplicate names in one run refused"

# a camera already used by another app (different scene) must be refused
# immediately, without first offering a "replace it?" confirm it can't honor
cc_other_scene_err() { printf "$1" | SCENE=indoor bash -c "PATH=$HERE/fakebin:\$PATH; . $ROOT/common.sh; export ASK_FROM_STDIN=1; collect_cameras garden" 2>&1; }
out="$(cc_other_scene_err '1\ngarden1\nrtsp://h/z\n')"
echo "$out" | grep -q 'another app' && pass "cross-app name collision refused immediately" || fail "cross-app name collision refused immediately"
echo "$out" | grep -q 'Replace it' && fail "cross-app collision should not offer to replace" || pass "cross-app collision should not offer to replace"

printf 'BROKER = "192.168.10.103"  # lab\nprint("x")\n' > "$T/listener.py"
BROKER=9.9.9.9
install_listener demo "$T/listener.py" "Demo listener" outdoor >/dev/null
D="$HOME/sixfab-apps/demo"
grep -q 'BROKER = "9.9.9.9"' "$D/listener.py" && pass "broker substituted" || fail "broker substituted"
assert_file "$D/camera_filter.py" "camera_filter copied"
assert_eq "garden1
garden2" "$(cat "$D/cameras.txt")" "cameras.txt lists scene cameras"
U="$HOME/.config/systemd/user/demo-automation.service"
assert_file "$U" "unit written"
grep -q "ExecStart=/opt/test-venv/bin/python $D/listener.py" "$U" && pass "unit uses the sixfab-dx venv python" || fail "unit uses the sixfab-dx venv python"
grep -q 'enable --now demo-automation.service' "$FAKE_LOG" && pass "enable --now called" || fail "enable --now called"

"$PYTHON" - "$T/cfg/config.yaml" <<'EOT'
import sys, yaml
p = sys.argv[1]; c = yaml.safe_load(open(p))
c["cameras"]["otherapp"] = {"detect": {"scene": "indoor"}}
yaml.safe_dump(c, open(p, "w"))
EOT
cp "$T/cfg/config.yaml" "$T/before2.yaml"
export ASK_FROM_STDIN=1 ASSUME_YES=1
echo otherapp | assert_fails "remove refuses another app's camera" remove_camera_flow outdoor demo
assert_eq "$(cat "$T/before2.yaml")" "$(cat "$T/cfg/config.yaml")" "config untouched after refused remove"

cp "$T/cfg/config.yaml" "$T/before3.yaml"
( DRY_RUN=1; echo garden2 | remove_camera_flow outdoor demo >/dev/null 2>&1 )
assert_eq "$(cat "$T/before3.yaml")" "$(cat "$T/cfg/config.yaml")" "remove_camera_flow dry run leaves config alone"

export ASK_FROM_STDIN=1 ASSUME_YES=1
echo garden2 | remove_camera_flow outdoor demo >/dev/null 2>&1
assert_eq "garden1" "$("$PYTHON" "$LIB/frigate_cfg.py" cameras "$T/cfg/config.yaml" outdoor)" "remove_camera_flow"
assert_eq "garden1" "$(cat "$D/cameras.txt")" "cameras.txt refreshed after remove"

finish
