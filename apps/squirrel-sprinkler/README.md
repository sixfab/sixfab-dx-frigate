# Squirrel Sprinkler

A single-class squirrel detector runs as a native Frigate detector on the DEEPX NPU and an MQTT listener publishes a trigger when a squirrel is seen. No valve is wired yet: the listener only logs and publishes (see "Physical hardware").

## What is in this folder

- `models.txt` - release tag, asset names and SHA-256 of the model. Model details and its license are in the GitHub release notes.
- `model/squirrel-only-labelmap.txt` - one class: `Squirrel`.
- `config/fragment.yaml` - the model entry and one template camera (`garden`); `install.sh` clones it once per camera you enter.
- `automation/sprinkler.py` - the MQTT listener: score >= 0.6, 30 second cooldown per camera, ignores cameras that are not in its `cameras.txt`.

## Install

Run `toolkit/install-frigate.sh` first if Frigate is not installed yet (see the repo README). Then:

```bash
cd apps/squirrel-sprinkler
./install.sh
```

The installer is interactive: it downloads the model from the `squirrel-sprinkler-v1.0.0` release, asks how many cameras you want to add (a name and an RTSP URL for each), merges them into Frigate's `config.yaml` (a timestamped `config.yaml.bak-*` copy is kept; YAML comments are not preserved), installs the MQTT listener as a user-level systemd service in `~/sixfab-apps/squirrel-sprinkler`, and offers to restart Frigate. Run it again later to add or remove cameras.

Non-interactive form: `./install.sh --rtsp-url rtsp://... --camera-name NAME --yes`. Other flags: `--broker HOST --container NAME --config-dir DIR --dry-run`.

This app uses Frigate scene `outdoor`. Frigate has only five scenes, one model each, so the installer stops with a clear message if the scene is already taken by another model.


## Verify

```bash
systemctl --user status squirrel-sprinkler-automation.service --no-pager -n 30
mosquitto_sub -h <broker-host> -t squirrel_sprinkler/trigger -v
docker exec frigate curl -s 'http://localhost:5000/api/events?label=Squirrel&limit=10'
```

Use your own container name instead of `frigate` if it differs.

## Physical hardware (not connected)

`trigger_sprinkler()` in `automation/sprinkler.py` only logs and publishes the trigger to `squirrel_sprinkler/trigger`. Once a solenoid valve or relay is wired, add the GPIO or relay control in that function and run `./install.sh` again to deploy the edited script (it overwrites the installed copy).

## Auto-start after reboot

The listener is a user-level systemd service. To start it after a reboot without logging in, run once: `sudo loginctl enable-linger $USER`
