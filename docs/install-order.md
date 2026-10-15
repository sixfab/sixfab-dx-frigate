# Install order

1. Install the `sixfab-dx` package (see the repo root README of `sixfab-dx-examples`, or wherever it's published). This gives you the shared Python environment at `/opt/sixfab-dx/venv`.
2. Run `toolkit/install-frigate.sh` once. It installs Frigate in Docker and, optionally, Mosquitto, and sets up the shared `config.yaml` that every app below merges into.
3. For each app you want: `cd apps/<project> && ./install.sh`.

## Release assets

Every app ships its model (and optional demo assets) as GitHub Release assets tagged `<app-name>-vX.Y.Z`. The installer reads `apps/<project>/models.txt` for the tag, file names, and SHA-256 values, and verifies each download.
