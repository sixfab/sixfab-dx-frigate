import glob, pathlib, subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def test_scripts_are_executable_in_git():
    """On the Pi, ./install.sh needs mode 100755 in the index (Windows hides this).

    Skipped while the files are not in the git index yet (nothing committed)."""
    names = ["toolkit/install-frigate.sh"]
    names += [pathlib.PurePath(n).as_posix() for n in sorted(glob.glob("apps/*/install.sh", root_dir=ROOT))]
    names += [pathlib.PurePath(n).as_posix() for n in sorted(glob.glob("toolkit/tests/shell/fakebin/*", root_dir=ROOT))]
    out = subprocess.run(["git", "ls-files", "-s", *names], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    modes = {line.split("	")[1]: line.split()[0] for line in out.splitlines()}
    if not modes:
        pytest.skip("scripts are not in the git index yet")
    bad = [n for n in names if modes.get(n) != "100755"]
    assert not bad, f"not executable in git: {bad}"
