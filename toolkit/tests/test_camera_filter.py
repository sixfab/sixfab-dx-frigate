import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from camera_filter import load_allowed, is_allowed


def test_missing_file_allows_all(tmp_path):
    assert load_allowed(str(tmp_path / "nope.txt")) is None
    assert is_allowed("any", None)


def test_file_restricts(tmp_path):
    p = tmp_path / "cameras.txt"
    p.write_text("a\n# c\n\nb\n")
    allowed = load_allowed(str(p))
    assert allowed == {"a", "b"}
    assert is_allowed("a", allowed) and not is_allowed("z", allowed)


def test_empty_file_allows_none(tmp_path):
    p = tmp_path / "cameras.txt"
    p.write_text("")
    assert not is_allowed("a", load_allowed(str(p)))
