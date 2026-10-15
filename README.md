# sixfab-dx-frigate

Five ready-made Frigate NVR apps for the Sixfab AI HAT+ with a DEEPX DX-M1M NPU, each adding one camera-based detection model and a small MQTT automation to a shared Frigate instance.

**Tested stack:** Raspberry Pi 5 (8 GB), Raspberry Pi OS Trixie (64-bit), Sixfab AI HAT+ with DEEPX DX-M1M.

## Projects

| App | Tagline | Runtime | Folder |
|---|---|---|---|
| Boss Detector | Person detection with Frigate on the DEEPX NPU | frigate | [apps/boss-detector](apps/boss-detector) |
| Porch Pirate | Package theft alerts with Frigate on the DEEPX NPU | frigate | [apps/porch-pirate](apps/porch-pirate) |
| Bird Species ID | A bird feeder camera that names the species | frigate | [apps/bird-species-id](apps/bird-species-id) |
| Squirrel Sprinkler | A squirrel detector that triggers an MQTT event, ready for a sprinkler valve | frigate | [apps/squirrel-sprinkler](apps/squirrel-sprinkler) |
| Smart Doorbell | Person detection plus Frigate face recognition on the DEEPX NPU | frigate | [apps/smart-doorbell](apps/smart-doorbell) |

## Install order

1. Install the `sixfab-dx` package (shared Python environment at `/opt/sixfab-dx/venv`).
2. Run `toolkit/install-frigate.sh` once (installs Frigate in Docker and, optionally, Mosquitto).
3. `cd apps/<project> && ./install.sh` for each app you want.

See [docs/install-order.md](docs/install-order.md) for details.

## Licensing

See [LICENSE](LICENSE) for this repo's own code (MIT). See [LICENSE-NOTES.md](LICENSE-NOTES.md) and [DEEPX-SDK-LICENSE.txt](DEEPX-SDK-LICENSE.txt) for the per-model licenses (AGPL-3.0, COCO, NABirds non-commercial, CC BY 4.0, DEEPX SDK); read these before redistributing any compiled model file.

## Standalone examples

Two DEEPX examples that don't use Frigate (retail-analytics, pose-estimation) live in the sibling [sixfab-dx-examples](https://github.com/sixfab/sixfab-dx-examples) repo, under `python_examples/`.
