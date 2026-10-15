import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from merge_config import deep_merge


def test_merge_into_empty_config():
    frag = {"models": [{"scene": "all", "path": "/p"}], "cameras": {"c": {"x": 1}}}
    assert deep_merge({}, frag) == frag


def test_models_matched_by_path_and_cameras_replaced_by_name():
    base = {"models": [{"scene": "all", "path": "/p", "width": 1}], "cameras": {"c": {"x": 1}, "d": {"y": 2}}}
    frag = {"models": [{"scene": "all", "path": "/p", "width": 2}, {"scene": "indoor", "path": "/q"}],
            "cameras": {"c": {"x": 9}}}
    out = deep_merge(base, frag)
    assert [m["path"] for m in out["models"]] == ["/p", "/q"]
    assert out["models"][0]["width"] == 2
    assert out["cameras"] == {"c": {"x": 9}, "d": {"y": 2}}


def test_null_models_and_cameras_in_base():
    # a config.yaml with "models:" or "cameras:" left empty loads as None
    frag = {"models": [{"scene": "all", "path": "/p"}], "cameras": {"c": {"x": 1}}}
    assert deep_merge({"models": None, "cameras": None}, frag) == frag
