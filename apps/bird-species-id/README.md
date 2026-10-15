# Bird Species ID

A bird feeder camera that names the species. One YOLO model, trained on
NABirds, runs as a native Frigate detector on the DEEPX NPU. Each detection
already carries the species name as its label, so there is no second
classifier on the CPU or the NPU.

```
RTSP bird stream -> Frigate (DEEPX detector, nabirds-new-model.dxnn)
                 -> object label = species name -> MQTT topics and Frigate UI
```

## What is in this folder

| Path | What it is |
| :---- | :---- |
| `model/nabirds-new/nabirds-new-model.dxnn` | The detector: 640x640 input, 555 NABirds classes. Ready-compiled. Lives in the GitHub release, not in git (see `models.txt`). |
| `model/nabirds-labelmap.txt` | The 555 class names, one per line, in the model's class order. |
| `config/fragment.yaml` | The model entry and the `birdfeeder` camera, merged into your Frigate `config.yaml` by `install.sh`. |
| `install.sh` | Downloads the model from the release, copies it and the labelmap into Frigate's `model_cache`, asks for your camera(s), merges the config and writes every species of the labelmap into `objects.track`. |
| `models.txt` | Release asset name, path and SHA-256 of the model. |

Model details and the model license are given in the GitHub release notes.

## Install

Run `toolkit/install-frigate.sh` first if Frigate is not installed yet (see the repo README). Then:

```bash
cd apps/bird-species-id
./install.sh
```

The installer is interactive: it downloads the model from the `bird-species-id-v1.0.0` release, asks how many cameras you want to add (a name and an RTSP URL for each), merges them into Frigate's `config.yaml` (a timestamped `config.yaml.bak-*` copy is kept; YAML comments are not preserved), and offers to restart Frigate. Run it again later to add or remove cameras.

Non-interactive form: `./install.sh --rtsp-url rtsp://... --camera-name NAME --yes`. Other flags: `--broker HOST --container NAME --config-dir DIR --dry-run`.

This app uses Frigate scene `outdoor_thermal`. Frigate has only five scenes, one model each, so the installer stops with a clear message if the scene is already taken by another model.


If the config still has the old bird classifiers (`classification.bird` or `classification.custom.*`), the installer switches them off because the YOLO labels replace them.

## Verify

Frigate publishes one topic per tracked species on the camera:

```sh
mosquitto_sub -h <broker-host> -t "frigate/<camera-name>/+" -v
```

Expect lines such as `frigate/<camera-name>/Red-bellied Woodpecker 1`, where the
number is how many birds of that species are in view, and `frigate/<camera-name>/all`
for all of them together.

## Things to know

- The labelmap names come from the NABirds class list. The `/` in names such as
  `Female/juvenile` was replaced by `-` because Frigate uses `/` as an MQTT topic
  separator, and doubled spaces were collapsed.
- Many NABirds names carry a variant in parentheses, for example
  `Painted Bunting (Female-juvenile)`. They are separate classes.
- The model only knows North American birds. A bird that is not in NABirds gets
  the label of the closest species the model knows.
- Detection runs at 3 fps (`detect.fps: 3`). On a Raspberry Pi 5 with the DX-M1M
  the model takes about 114 ms per frame with nothing else on the NPU, so 5 fps
  made Frigate skip frames.
- Species labels were tried on a looping test video, not on a measured set of
  North American birds. No accuracy figure exists.
