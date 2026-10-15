# Structure

## `toolkit/` vs `apps/<name>/`

- `toolkit/` holds everything shared across all Frigate apps: `install-frigate.sh` (sets up Frigate + Mosquitto once), `common.sh` (helpers: both generic ones like `fetch_assets`/`release_url`, and Frigate-specific ones like `merge_fragment`/`discover_frigate`), `frigate_cfg.py` (reads/edits Frigate's `config.yaml`), `merge_config.py` (merges a fragment into the shared config without clobbering other apps), `camera_filter.py` (which cameras an MQTT listener reacts to), and `tests/` for all of the above.
- `apps/<name>/` holds one app: `install.sh`, `config/fragment.yaml` (the Frigate model+camera entry this app contributes), `model/` + `models.txt` (the model binary and its GitHub-release manifest), `README.md`, `project.yaml`, and (if the app has an MQTT listener) `automation/` plus its own `tests/`.

An app's `install.sh` sources `toolkit/common.sh`, never the other way around; the toolkit has no knowledge of individual apps.

## When a project should graduate to its own repo

Move an app out of `apps/<name>/` into its own repository when any of these is true:
- It gets outside contributors who need their own PR/issue flow separate from the other 4 apps.
- It needs its own release cadence (shipping new model versions far more or less often than the rest).
- It ships hardware files (CAD, PCB, wiring diagrams); those don't belong alongside pure software apps.
- Its own files (model + demo assets, excluding what's fetched from GitHub Releases) exceed 50 MB in the repo itself.

## Release tag scheme

Every app tags its model release as `<app-name>-vX.Y.Z` (for example `porch-pirate-v1.0.0`), matching the `# TAG:` line at the top of that app's `models.txt`. The installer's `fetch_assets` (in `toolkit/common.sh`) reads that tag and downloads the matching GitHub Release assets, verifying each by SHA-256.
