# Porch Pirate

Package theft alerts with Frigate on the DEEPX NPU. A custom 5-class model (package, person, car, truck, motorcycle) feeds a small state machine over MQTT.

## What is in this folder

- `models.txt` - release tag, asset names and SHA-256 of the model.
- `model/people-and-cardboxes/labelmap.txt` - class order: 0 package, 1 person, 2 car, 3 truck, 4 motorcycle.
- `config/fragment.yaml` - the model entry and one template camera with a generic `frontdoor_zone`. `install.sh` clones it once per camera you enter.
- `automation/porch_watch.py` - listens to `frigate/events`. It remembers who is in the zone when a package first appears, flags anyone else who shows up while the package is there, and publishes `THEFT_ALERT_SUSPECTED` to `porch_pirate/theft_alert` if the package then disappears. State is kept per camera, and cameras that are not in `cameras.txt` are ignored.

## Install

Run `toolkit/install-frigate.sh` first if Frigate is not installed yet (see the repo README). Then:

```bash
cd apps/porch-pirate
./install.sh
```

The installer is interactive: it downloads the model from the `porch-pirate-v1.0.0` release, asks how many cameras you want to add (a name and an RTSP URL for each), merges them into Frigate's `config.yaml` (a timestamped `config.yaml.bak-*` copy is kept; YAML comments are not preserved), installs the MQTT listener as a user-level systemd service in `~/sixfab-apps/porch-pirate`, and offers to restart Frigate. Run it again later to add or remove cameras.

Non-interactive form: `./install.sh --rtsp-url rtsp://... --camera-name NAME --yes`. Other flags: `--broker HOST --container NAME --config-dir DIR --dry-run`.

This app uses Frigate scene `indoor`. Frigate has only five scenes, one model each, so the installer stops with a clear message if the scene is already taken by another model.

The zone the installer adds is a generic rectangle. Redraw it in the Frigate UI (camera > Zones) so it follows your own porch.

## Verify

```bash
systemctl --user status porch-pirate-automation.service --no-pager -n 30
mosquitto_sub -h <broker-host> -t porch_pirate/theft_alert -v
curl -s http://localhost:5000/api/stats
```

## Known caveat

Frigate assigns a new track id when the same person leaves and re-enters the frame (no re-identification), so "different person" really means "different track id". A real identity check would need a face recognition sub label comparison.
