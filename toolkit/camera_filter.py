"""Which cameras a listener should react to. cameras.txt sits next to the script."""
import os


def load_allowed(path=None):
    """Return a set of camera names, or None when cameras.txt does not exist (allow all)."""
    path = path or os.path.join(os.path.dirname(os.path.abspath(__file__)), "cameras.txt")
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        return {line.strip() for line in f if line.strip() and not line.startswith("#")}


def is_allowed(camera, allowed) -> bool:
    return allowed is None or camera in allowed
