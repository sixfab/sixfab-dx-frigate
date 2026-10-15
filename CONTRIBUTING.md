# Contributing

## Adding a new Frigate app

1. Create `apps/<your-app>/` using `apps/boss-detector/` as the template:
   - `install.sh`: source `toolkit/common.sh` via `. "$HERE/../../toolkit/common.sh"`, use `fetch_assets` to pull your model from a GitHub Release, use `merge_fragment`/`discover_frigate` (from `toolkit/common.sh`) to add your camera+model into the shared Frigate `config.yaml` without touching other apps' entries.
   - `config/fragment.yaml`: the model + camera block your app contributes.
   - `model/` + `models.txt`: a `# TAG: <your-app>-vX.Y.Z` line, then one row per asset: `name  path  sha256  [optional]`. Do not commit the model binary itself; it ships as a GitHub Release asset.
   - `project.yaml`: `name`, `title`, `tagline`, `runtime: frigate`, `extra_hardware` (true only if the app needs wiring/hardware beyond a camera), `model_license`, `release_prefix`.
   - `README.md`: what it does, install steps, how to verify it's working.
   - If your app has an MQTT listener, put it under `automation/` and add `apps/<your-app>/tests/test_<listener>.py` following `apps/porch-pirate/tests/test_porch_watch.py`.
2. Add your model's license notes as a new section in `LICENSE-NOTES.md` (same shape as the existing entries) and, if it's dxcom-compiled, confirm `DEEPX-SDK-LICENSE.txt` already covers it (it does, repo-wide).
3. If you touch `toolkit/`, add or update a test under `toolkit/tests/`.

## Running tests

```
cd toolkit/tests && pytest .
bash toolkit/tests/shell/test_common.sh
bash toolkit/tests/shell/test_frigate.sh
bash toolkit/tests/shell/test_setup.sh
bash toolkit/tests/shell/test_installers.sh
cd ../../apps/porch-pirate/tests && pytest .
```

## PR expectations

- No behavior changes to an existing app or to `toolkit/` without discussion first; these apps run unattended on other people's hardware.
- Any model change updates `models.txt` (new tag, new SHA-256) and the matching `LICENSE-NOTES.md` section.
- Keep `project.yaml` accurate; it's read by tooling outside this repo.
- Tests pass: `toolkit/tests/` and the touched app's own tests, plus `shellcheck` on any shell script you add or edit.
