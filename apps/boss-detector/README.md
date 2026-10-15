# Boss Detector

Person detection with Frigate on the DEEPX NPU (pretrained `yolov8n-ppu-coco80.dxnn`, COCO-80, no custom training). A small MQTT listener publishes an alert on every person sighting.

## What is in this folder

- `models.txt` - release tag, asset names and SHA-256 of the model.
- `model/coco80-labelmap.txt` - the standard COCO-80 labelmap (person = class 0).
- `config/fragment.yaml` - the model entry and one template camera; `install.sh` clones it once per camera you enter.
- `automation/notify.py` - the MQTT listener. It reacts to both `new` and `update` events (so the alert fires as soon as a person is seen) with a 5 second cooldown, and ignores cameras that are not in its `cameras.txt`.

## Install

Run `toolkit/install-frigate.sh` first if Frigate is not installed yet (see the repo README). Then:

```bash
cd apps/boss-detector
./install.sh
```

The installer is interactive: it downloads the model from the `boss-detector-v1.0.0` release, asks how many cameras you want to add (a name and an RTSP URL for each), merges them into Frigate's `config.yaml` (a timestamped `config.yaml.bak-*` copy is kept; YAML comments are not preserved), installs the MQTT listener as a user-level systemd service in `~/sixfab-apps/boss-detector`, and offers to restart Frigate. Run it again later to add or remove cameras.

Non-interactive form: `./install.sh --rtsp-url rtsp://... --camera-name NAME --yes`. Other flags: `--broker HOST --container NAME --config-dir DIR --dry-run`.

This app uses Frigate scene `indoor_thermal`. Frigate has only five scenes, one model each, so the installer stops with a clear message if the scene is already taken by another model.

## Verify

```bash
systemctl --user status boss-detector-automation.service --no-pager -n 30
mosquitto_sub -h <broker-host> -t boss_detector/alert -v
# boss_detector/alert {"camera": "cam1", "score": 0.91, "timestamp": 1791267003.4}
curl -s http://localhost:5000/api/stats
```

## Next step (optional)

`trigger_alert()` in `automation/notify.py` logs and publishes the alert but does nothing else. Wire in a real action (sound, light, webhook, Home Assistant) there, then run `./install.sh` again to deploy the edited script.
