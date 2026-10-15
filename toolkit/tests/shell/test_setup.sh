#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
. "$HERE/lib.sh"
export PYTHON="${PYTHON:-python3}" SIXFAB_TEST=1 SIXFAB_NO_TTY=1 PATH="$HERE/fakebin:$PATH"
T="$(mktemp -d)"
export HOME="$T/home"; mkdir -p "$HOME"
unset FRIGATE_IMAGE

# The image is an open item: stop with a clear message instead of guessing.
out="$(bash "$ROOT/install-frigate.sh" --yes --dry-run --mosquitto yes 2>&1)"; rc=$?
assert_eq "1" "$rc" "install-frigate refuses without FRIGATE_IMAGE"
echo "$out" | grep -q 'FRIGATE_IMAGE' && pass "names FRIGATE_IMAGE" || fail "names FRIGATE_IMAGE"

export FRIGATE_IMAGE="example.invalid/frigate:deepx"
out="$(bash "$ROOT/install-frigate.sh" --yes --dry-run --mosquitto yes 2>&1)"; rc=$?
assert_eq "0" "$rc" "dry run succeeds with all settings"
echo "$out" | grep -q 'DRY: sudo apt-get install -y python3-yaml' && pass "installs helper packages" || fail "installs helper packages"
echo "$out" | grep -q 'DRY: sudo apt-get install -y mosquitto' && pass "installs mosquitto" || fail "installs mosquitto"
echo "$out" | grep -q 'DRY: docker run' && pass "starts frigate" || fail "starts frigate"
echo "$out" | grep -q -- '--device /dev/dxrt0:/dev/dxrt0' && pass "passes the NPU device" || fail "passes the NPU device"
echo "$out" | grep -q -- '--shm-size=256m' && pass "shm size" || fail "shm size"
echo "$out" | grep -q -- '--network host' && pass "uses host networking" || fail "uses host networking"
echo "$out" | grep -q -- 'DXRT_DYNAMIC_IPC_ENDPOINT=@dxrt_dynamic_ipc.sock' && pass "points DX-RT at the abstract IPC socket" || fail "points DX-RT at the abstract IPC socket"

export HOME="$T/home2"; mkdir -p "$HOME"   # fresh home: install-frigate.sh never overwrites an existing config
bash "$ROOT/install-frigate.sh" --yes --mosquitto no --broker 10.2.2.2 --dry-run >"$T/o2" 2>&1
grep -q 'apt-get install -y mosquitto' "$T/o2" && fail "mosquitto skipped" || pass "mosquitto skipped"
grep -q 'host: 10.2.2.2' "$HOME/frigate/config/config.yaml" && pass "broker host written to config" || fail "broker host written to config"
grep -q 'models: \[\]' "$HOME/frigate/config/config.yaml" && pass "empty models list" || fail "empty models list"

# fresh Pi without Docker: install it, then use sudo for this run (the docker group is not active yet)
export HOME="$T/home3"; mkdir -p "$HOME"
out="$(SIXFAB_FAKE_NO_DOCKER=1 bash "$ROOT/install-frigate.sh" --yes --mosquitto no --broker 1.1.1.1 --dry-run 2>&1)"
echo "$out" | grep -q 'DRY: sh -c curl -fsSL https://get.docker.com' && pass "installs docker when missing" || fail "installs docker when missing"
echo "$out" | grep -q 'DRY: sudo docker run' && pass "uses sudo docker right after installing it" || fail "uses sudo docker right after installing it"

finish
