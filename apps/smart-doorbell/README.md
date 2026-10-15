# Smart Doorbell

Person detection on the DEEPX NPU (`yolov8-n_640x640_ppu.dxnn`, DeepX reference COCO-80 model) plus Frigate face recognition (ArcFace `model_size: large`, on the CPU). There is no listener: this app only adds the model, face recognition and your door camera(s).

## What is in this folder

- `models.txt` - release tag, asset names and SHA-256 of the model.
- `model/coco80-labelmap.txt` - the standard COCO-80 labelmap.
- `config/fragment.yaml` - the model entry, face recognition settings and one template camera with a `frontdoor_zone`.

## Install

Run `toolkit/install-frigate.sh` first if Frigate is not installed yet (see the repo README). Then:

```bash
cd apps/smart-doorbell
./install.sh
```

The installer is interactive: it downloads the model from the `smart-doorbell-v1.0.0` release, asks how many cameras you want to add (a name and an RTSP URL for each), merges them into Frigate's `config.yaml` (a timestamped `config.yaml.bak-*` copy is kept; YAML comments are not preserved), and offers to restart Frigate. Run it again later to add or remove cameras.

Non-interactive form: `./install.sh --rtsp-url rtsp://... --camera-name NAME --yes`. Other flags: `--broker HOST --container NAME --config-dir DIR --dry-run`.

This app uses Frigate scene `all`. Frigate has only five scenes, one model each, so the installer stops with a clear message if the scene is already taken by another model.

## Enrolling a face

Open `https://<pi-ip>:8971/faces` directly (the sidebar link only shows in browsers Frigate classifies as "desktop"). Upload one clear, front-facing photo per person, then refine from the Train tab as Frigate captures real recognition attempts. Face recognition takes roughly 600-800 ms per inference on the Pi 5 CPU, depending on the load from other cameras and models.

## Troubleshooting

- Camera image is rotated: a physical mounting issue, rotate the camera.
- `detection_fps: 0` for a camera: a known Frigate stationary-scene quirk. Toggle `detect` off and on for the camera, or restart the stream to force fresh motion.
- No recognition results although `face_recognition_speed` is nonzero in `/api/stats`: the face library is empty, nobody is enrolled yet.
