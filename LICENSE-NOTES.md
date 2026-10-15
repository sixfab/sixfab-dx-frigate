# License notes: sixfab-dx-frigate

Per-model license notes for the 5 Frigate apps in this repo, copied verbatim
from the release staging notes (no wording changed). See
`DEEPX-SDK-LICENSE.txt` in this same folder for the DEEPX SDK terms referenced
in each section below.

---

# License notes: boss-detector-v1.0.0

## Model file
- `yolov8n-ppu-coco80.dxnn`
- SHA-256: `15493c7716478484e05c57d9afa07328d77c07b75e8ebec4260db7c76d3d7e66`
- Matches `apps/boss-detector/models.txt` in this repo.

## What this is
Stock Ultralytics YOLOv8n object detector, COCO-80 classes, PPU-compiled for the
DeepX NPU. No custom training: the "person" class already exists in COCO-80
(class 0) and is used as-is for the boss/patron detection scene.

## DEEPX compiler (dxcom)
Compiled with DEEPX's `dxcom` toolchain. See `DEEPX-SDK-LICENSE.txt` in the
parent folder for DEEPX's license terms.

## License chain
- **Base weights/architecture:** Ultralytics YOLOv8 → **AGPL-3.0**
  (https://github.com/ultralytics/ultralytics, `LICENSE`). AGPL-3.0 is a
  copyleft license: distributing this model (including as a compiled `.dxnn`
  artifact) as part of a product obligates making the corresponding source
  available under AGPL-3.0, unless Sixfab/the publisher holds an Ultralytics
  Enterprise license that supersedes this.
- **Training data:** COCO 2017 (Common Objects in Context,
  https://cocodataset.org); images are CC BY 4.0, annotations are licensed
  for both research and commercial use per the COCO terms of use. No
  additional restriction beyond the AGPL-3.0 note above.

## Attribution text (for a NOTICE/credits section)
> Object detector based on Ultralytics YOLOv8 (AGPL-3.0), trained on the
> COCO dataset (cocodataset.org).

---

# License notes: porch-pirate-v1.0.0

## Model file
- `people-and-cardboxes.dxnn`
- SHA-256: `6087525b9f8470a1a464bd205ddcae87ea918aacf020d59c1285c870dafe2ff1`
- Matches `apps/porch-pirate/models.txt` in this repo.

## What this is
Custom-trained YOLOv8-family detector, 5 classes: `package`, `person`,
`car`, `truck`, `motorcycle`. Built from two merged sources
(`dataset-build/build_coco_subset.py` + `dataset-build/filter_package_zip.py`):

1. **COCO 2017** subset (val2017 + train2017), class-balanced pull of
   `person`/`car`/`truck`/`motorcycle` images, remapped to this model's
   5-class scheme.
2. **A Roboflow dataset named "Package and label detection"** (per the
   script's own docstring), filtered down to just its `package` class,
   remapped to class 0.

## DEEPX compiler (dxcom)
Compiled with DEEPX's `dxcom` toolchain. See `DEEPX-SDK-LICENSE.txt` in the
parent folder for DEEPX's license terms.

## License chain
- **Base architecture/training framework:** Ultralytics YOLOv8 → **AGPL-3.0**
  (same framework used across every other custom model in this project
  family). Copyleft: distributing this model as part of a product obligates
  making the corresponding source available under AGPL-3.0, unless
  Sixfab/the publisher holds an Ultralytics Enterprise license.
- **COCO portion:** COCO 2017 (https://cocodataset.org); CC BY 4.0 images,
  no additional restriction.
- **Package portion:** a Roboflow Universe dataset ("Package and label
  detection"): **CC BY 4.0** (Roboflow Universe's standard license for
  public datasets, confirmed 2026-10-15). The exact project URL/account
  couldn't be re-identified (not saved before the source zip was deleted),
  but the license terms are the same CC BY 4.0 attribution requirement as
  the squirrel-sprinkler datasets elsewhere in this project.

## Attribution text
> Object detector based on Ultralytics YOLOv8 (AGPL-3.0), trained on a
> combination of the COCO dataset (cocodataset.org) and a Roboflow
> Universe "Package and label detection" dataset, both CC BY 4.0.

---

# License notes: bird-species-id-v1.0.0

## NON-COMMERCIAL USE ONLY

## Model file
- `nabirds-new-model.dxnn`
- SHA-256: `eb0010e477085aa4502a992bf5c6788bfe207c6f1ec9254f9b0a126b6c30f939`
- Matches `apps/bird-species-id/models.txt` in this repo.

## What this is
Custom-trained YOLOv8-family detector (555 NABirds species classes, trained
end-to-end as a detector+classifier in one shot, no separate classification
head). Compiled with the plain `dxcom` CLI (no PPU) for the DeepX NPU.

## DEEPX compiler (dxcom)
Compiled with DEEPX's `dxcom` toolchain. See `DEEPX-SDK-LICENSE.txt` in the
parent folder for DEEPX's license terms.

## License chain
- **Base architecture/training framework:** Ultralytics YOLOv8 → **AGPL-3.0**
  (the ONNX export graph shows Ultralytics' standard DFL→distance→cxcywh box
  decode baked in, confirming the Ultralytics training path was used).
- **Training data: NABirds** (https://dl.allaboutbirds.org/nabirds);
  **non-commercial use policy.** NABirds' terms restrict use of the dataset
  (and models trained on it) to non-commercial purposes. This is a **harder
  restriction than AGPL-3.0** and is the one that governs this model.

## Restriction (confirmed 2026-10-13)
This model **must be published and used as non-commercial only** until the
NABirds licensing question is formally resolved with the dataset's
maintainers. Do not use in a paid product, commercial demo, or any
revenue-generating deployment. This warning must stay attached to the model
wherever it's redistributed (GitHub Release description, models.txt,
project README).

## Attribution text
> Bird species detector trained on the NABirds dataset
> (dl.allaboutbirds.org/nabirds, non-commercial use only), base architecture
> Ultralytics YOLOv8 (AGPL-3.0). NON-COMMERCIAL USE ONLY.

---

# License notes: squirrel-sprinkler-v1.0.0

## Model file
- `squirrel-detector-model.dxnn`
- SHA-256: `5f285b3c47d9457c691b1985c47448b887d71acab8ca40a19688bb006b0eb9ef`
- Matches `apps/squirrel-sprinkler/models.txt` in this repo.

## What this is
Custom-trained **YOLOv8m** single-class ("squirrel") detector, trained with
the Ultralytics framework (confirmed 2026-10-13), compiled for the
DeepX NPU. This supersedes the two earlier candidates still sitting in the
archive for reference (`squirrel-yolov5.dxnn`, MIT-licensed YOLOv5; and
`yolov8n-oiv7-preopt*.dxnn`, AGPL-licensed Ultralytics YOLOv8n-OIV7); neither
of those is the file this release ships.

## DEEPX compiler (dxcom)
Compiled with DEEPX's `dxcom` toolchain. See `DEEPX-SDK-LICENSE.txt` in the
parent folder for DEEPX's license terms.

## License chain
- **Base architecture/training framework:** Ultralytics YOLOv8m →
  **AGPL-3.0** (https://github.com/ultralytics/ultralytics, `LICENSE`).
  Copyleft: distributing this model as part of a product obligates making
  the corresponding source available under AGPL-3.0, unless Sixfab/the
  publisher holds an Ultralytics Enterprise license that supersedes this.
- **Training data:** two merged Roboflow Universe datasets
  (`dataset-build/raw_v1/` and `dataset-build/raw_detector/`), both
  single-class "squirrel", both licensed **CC BY 4.0** (attribution
  required, commercial use allowed):
  1. **"Squirrel V1"**: workspace `squirrel-detect`, project `squirrel-v1`,
     8518 images.
     https://universe.roboflow.com/squirrel-detect/squirrel-v1
  2. **"Squirrel Detector 1.1"**: workspace `warren-wiens-d0d4p`, project
     `squirrel-detector-1.1`, 5102 images.
     https://universe.roboflow.com/warren-wiens-d0d4p/squirrel-detector-1.1

## Attribution text (required by CC BY 4.0)
> Squirrel detector based on Ultralytics YOLOv8m (AGPL-3.0), trained on a
> combination of two Roboflow Universe datasets licensed under CC BY 4.0:
> "Squirrel V1" by squirrel-detect
> (universe.roboflow.com/squirrel-detect/squirrel-v1) and
> "Squirrel Detector 1.1" by warren-wiens-d0d4p
> (universe.roboflow.com/warren-wiens-d0d4p/squirrel-detector-1.1).

---

# License notes: smart-doorbell-v1.0.0

## Model file
- `yolov8-n_640x640_ppu.dxnn`
- SHA-256: `874e5a8d5eb10dd207ca637e0f14f251871691e1c1a4002e86086bab9de8ee60`
- Matches `apps/smart-doorbell/models.txt` in this repo.

## What this is
Stock Ultralytics YOLOv8n object detector, COCO-80 classes, PPU-compiled for
the DeepX NPU, run with `scene: all` for general person/object detection at
the door. Same base model family as boss-detector, no custom training.

## DEEPX compiler (dxcom)
Compiled with DEEPX's `dxcom` toolchain. See `DEEPX-SDK-LICENSE.txt` in the
parent folder for DEEPX's license terms.

## License chain
- **Base weights/architecture:** Ultralytics YOLOv8 → **AGPL-3.0**
  (https://github.com/ultralytics/ultralytics, `LICENSE`). Copyleft:
  distributing this model as part of a product obligates making the
  corresponding source available under AGPL-3.0, unless Sixfab/the publisher
  holds an Ultralytics Enterprise license that supersedes this.
- **Training data:** COCO 2017 (https://cocodataset.org); images CC BY 4.0,
  annotations licensed for research and commercial use. No additional
  restriction.

## Attribution text
> Object detector based on Ultralytics YOLOv8 (AGPL-3.0), trained on the
> COCO dataset (cocodataset.org).
