"""Merge a project's config fragment into the shared Frigate config.yaml
running on the Pi, without clobbering other projects' cameras/models.

Several apps share one Frigate instance (one DX-M1 device), so
each app's install.sh MERGES its camera + model into the live
config instead of overwriting it.

Merge rules:
  - top-level scalars/dicts: fragment wins, recursively merged into base
  - "models" list: entries matched by "path"; same path -> replaced,
    new path -> appended (dedupes re-runs of install.sh)
  - "cameras" dict: merged key by key (fragment's camera replaces same-name
    camera, other cameras untouched)

Usage: python merge_config.py <base.yaml> <fragment.yaml> <out.yaml>
"""
import sys
import yaml


def deep_merge(base: dict, fragment: dict) -> dict:
    result = dict(base)
    for key, value in fragment.items():
        if key == "models" and isinstance(value, list):
            existing = list(result.get("models") or [])
            by_path = {m.get("path"): i for i, m in enumerate(existing) if isinstance(m, dict)}
            for m in value:
                if m.get("path") in by_path:
                    existing[by_path[m["path"]]] = m
                else:
                    existing.append(m)
            result["models"] = existing
        elif key == "cameras" and isinstance(value, dict):
            cams = dict(result.get("cameras") or {})
            cams.update(value)
            result["cameras"] = cams
        elif isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result


if __name__ == "__main__":
    base_path, fragment_path, out_path = sys.argv[1:4]
    with open(base_path, encoding="utf-8") as f:
        base = yaml.safe_load(f) or {}
    with open(fragment_path, encoding="utf-8") as f:
        fragment = yaml.safe_load(f) or {}
    merged = deep_merge(base, fragment)
    with open(out_path, "w", encoding="utf-8") as f:
        yaml.safe_dump(merged, f, sort_keys=False, allow_unicode=True)
    print(f"Merged {fragment_path} into {base_path} -> {out_path}")
