#!/usr/bin/env bash
# Optional: Frigate (camera NVR with DEEPX object detection) in Docker, plus an MQTT broker.
# Only the Frigate-based projects (boss-detector, porch-pirate, squirrel-sprinkler,
# smart-doorbell, bird-species-id) need this. retail-analytics and pose-estimation do not.
#
# Prerequisite: the sixfab-dx package (see the README in the repo root).
#
# Required setting (no default on purpose):
#   FRIGATE_IMAGE   DEEPX-enabled Frigate image
# Flags: --mosquitto yes|no  --broker HOST  --yes  --dry-run  --help
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/common.sh"

MOSQUITTO=""
while [ $# -gt 0 ]; do
    case "$1" in
        --mosquitto) MOSQUITTO="${2:?--mosquitto needs yes or no}"; shift 2 ;;
        --broker)    BROKER="${2:?--broker needs a host}"; shift 2 ;;
        --yes)       ASSUME_YES=1; shift ;;
        --dry-run)   DRY_RUN=1; shift ;;
        -h|--help)   sed -n '2,11p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) die "unknown flag '$1' (try --help)" ;;
    esac
done

[ -n "${FRIGATE_IMAGE:-}" ] || die "FRIGATE_IMAGE is not set (the DEEPX-enabled Frigate image)."

FRIGATE_HOME="${FRIGATE_HOME:-$HOME/frigate}"

echo "== 1/4: checking the DEEPX runtime and helper packages =="
if [ "${DRY_RUN:-0}" != "1" ]; then
    command -v dxrt-cli >/dev/null 2>&1 || die "dxrt-cli not found. Install the sixfab-dx package first (see the README in the repo root)."
    test -c /dev/dxrt0 || echo "WARNING: /dev/dxrt0 is missing. Check that the DEEPX card is seated and reboot after installing sixfab-dx."
fi
run sudo apt-get install -y python3-yaml ffmpeg curl

echo "== 2/4: MQTT broker =="
if [ -z "$MOSQUITTO" ]; then
    if confirm "Install Mosquitto (MQTT broker) on this Pi?"; then MOSQUITTO=yes; else MOSQUITTO=no; fi
fi
case "$MOSQUITTO" in
    yes) run sudo apt-get install -y mosquitto mosquitto-clients
         if [ "${DRY_RUN:-0}" != "1" ]; then
             printf 'listener 1883\nallow_anonymous true\n' | sudo tee /etc/mosquitto/conf.d/sixfab.conf >/dev/null
         else echo "DRY: write /etc/mosquitto/conf.d/sixfab.conf"; fi
         run sudo systemctl enable --now mosquitto
         run sudo systemctl restart mosquitto
         BROKER="127.0.0.1" ;;
    no)  [ -n "${BROKER:-}" ] || BROKER="$(ask 'Address of your existing MQTT broker: ')"
         [ -n "$BROKER" ] || die "an MQTT broker address is required (pass --broker HOST)." ;;
    *)   die "--mosquitto must be yes or no" ;;
esac

echo "== 3/4: Docker =="
DOCKER=docker
if [ "${SIXFAB_FAKE_NO_DOCKER:-0}" = "1" ] || ! command -v docker >/dev/null 2>&1; then
    run sh -c 'curl -fsSL https://get.docker.com | sh'
    run sudo usermod -aG docker "${USER:-$(id -un)}"
    DOCKER="sudo docker"   # the docker group is not active in this shell yet
    say "   Docker installed. Log out and back in (or reboot) before running the project installers."
fi

echo "== 4/4: Frigate =="
mkdir -p "$FRIGATE_HOME/config/model_cache" "$FRIGATE_HOME/media"
if [ ! -f "$FRIGATE_HOME/config/config.yaml" ]; then
    cat > "$FRIGATE_HOME/config/config.yaml" <<EOT
mqtt:
  enabled: true
  host: $BROKER
  port: 1883
  topic_prefix: frigate
models: []
cameras: {}
EOT
fi
run $DOCKER pull "$FRIGATE_IMAGE"
run $DOCKER rm -f frigate || true
run $DOCKER run -d --name frigate --restart unless-stopped \
    --network host \
    -e DXRT_DYNAMIC_IPC_ENDPOINT=@dxrt_dynamic_ipc.sock \
    --device /dev/dxrt0:/dev/dxrt0 --shm-size=256m \
    -v "$FRIGATE_HOME/config:/config" -v "$FRIGATE_HOME/media:/media/frigate" \
    "$FRIGATE_IMAGE"

cat <<EOT

Frigate install complete.
  Frigate UI:  https://$(hostname -I 2>/dev/null | awk '{print $1}'):8971
  MQTT broker: $BROKER
Next: cd apps/boss-detector && ./install.sh
EOT
