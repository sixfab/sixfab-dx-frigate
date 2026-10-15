"""Read and edit a Frigate config.yaml for the install scripts.

Used as a module by the tests and as a CLI by lib/common.sh. All YAML goes
through PyYAML so RTSP URLs with special characters are never put through sed.
"""
import copy
import re
import sys

import yaml

NAME_RE = re.compile(r"^[a-z0-9_]+$")


class ConfigError(Exception):
    pass


def load(path: str) -> dict:
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def dump(data: dict, path: str) -> None:
    with open(path, "w", encoding="utf-8") as f:
        yaml.safe_dump(data, f, sort_keys=False, allow_unicode=True)


def broker_host(config: dict):
    return (config.get("mqtt") or {}).get("host")


def used_scenes(config: dict) -> dict:
    return {
        m["scene"]: m.get("path")
        for m in (config.get("models") or [])
        if isinstance(m, dict) and "scene" in m
    }


def check_scene_slot(config: dict, fragment: dict) -> None:
    used = used_scenes(config)
    for m in fragment.get("models") or []:
        scene = m["scene"]
        for other_scene, other_path in used.items():
            if other_path == m["path"] and other_scene != scene:
                raise ConfigError(
                    f"model {m['path']} is already configured for scene '{other_scene}'; "
                    f"merging it as '{scene}' would orphan that scene's cameras."
                )
        if scene in used and used[scene] != m["path"]:
            raise ConfigError(
                f"scene '{scene}' is already used by {used[scene]}. "
                "Frigate has only 5 scenes (all, indoor, outdoor, indoor_thermal, "
                "outdoor_thermal), one model each."
            )


def check_names(config: dict, scene: str, names: list) -> None:
    cams = config.get("cameras") or {}
    for name in names:
        if not NAME_RE.match(name):
            raise ConfigError(f"camera name '{name}' must use only a-z, 0-9 and _")
        existing = cams.get(name)
        if existing is not None and (existing.get("detect") or {}).get("scene") != scene:
            raise ConfigError(f"camera '{name}' already exists and belongs to another app; pick another name")


def clone_cameras(fragment: dict, pairs: list) -> dict:
    cams = fragment.get("cameras") or {}
    if not cams:
        raise ConfigError("fragment has no camera template")
    template = next(iter(cams.values()))
    out = copy.deepcopy(fragment)
    out["cameras"] = {}
    for name, url in pairs:
        cam = copy.deepcopy(template)
        cam["ffmpeg"]["inputs"][0]["path"] = url
        out["cameras"][name] = cam
    return out


def list_cameras(config: dict, scene: str) -> list:
    return [
        n for n, c in (config.get("cameras") or {}).items()
        if (c.get("detect") or {}).get("scene") == scene
    ]


def camera_scene(config: dict, name: str):
    cam = (config.get("cameras") or {}).get(name)
    if cam is None:
        return None
    return (cam.get("detect") or {}).get("scene")


def remove_camera(config: dict, name: str) -> dict:
    cams = config.get("cameras") or {}
    if name not in cams:
        raise ConfigError(f"camera '{name}' not found")
    out = copy.deepcopy(config)
    del out["cameras"][name]
    return out


def expand_species(fragment: dict, names: list) -> dict:
    out = copy.deepcopy(fragment)
    for cam in out["cameras"].values():
        cam["objects"] = {
            "track": list(names),
            "filters": {n: {"min_score": 0.3, "threshold": 0.4} for n in names},
        }
    return out


def disable_classifiers(config: dict) -> bool:
    cl = config.get("classification") or {}
    changed = False
    if isinstance(cl.get("bird"), dict) and cl["bird"].get("enabled"):
        cl["bird"]["enabled"] = False
        changed = True
    for v in (cl.get("custom") or {}).values():
        if isinstance(v, dict) and v.get("enabled"):
            v["enabled"] = False
            changed = True
    return changed


def _main(argv: list) -> int:
    sys.stdout.reconfigure(newline="\n")  # same bytes on Windows and the Pi
    cmd, args = argv[0], argv[1:]
    try:
        if cmd == "broker":
            print(broker_host(load(args[0])) or "")
        elif cmd == "check-scene":
            check_scene_slot(load(args[0]), load(args[1]))
        elif cmd == "check-names":
            check_names(load(args[0]), args[1], args[2:])
        elif cmd == "clone":
            pairs = [tuple(a.split("=", 1)) for a in args[2:]]
            dump(clone_cameras(load(args[0]), pairs), args[1])
        elif cmd == "names":
            print("\n".join((load(args[0]).get("cameras") or {}).keys()))
        elif cmd == "cameras":
            print("\n".join(list_cameras(load(args[0]), args[1])))
        elif cmd == "camera-scene":
            print(camera_scene(load(args[0]), args[1]) or "")
        elif cmd == "remove":
            dump(remove_camera(load(args[0]), args[2]), args[1])
        elif cmd == "species":
            names = [n for n in open(args[1], encoding="utf-8").read().splitlines() if n]
            dump(expand_species(load(args[0]), names), args[2])
            print(f"   {len(names)} species written to objects.track")
        elif cmd == "disable-classifiers":
            cfg = load(args[0])
            if disable_classifiers(cfg):
                dump(cfg, args[0])
                print("   switched off the old bird classifiers")
        else:
            raise ConfigError(f"unknown command {cmd}")
    except ConfigError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(_main(sys.argv[1:]))
