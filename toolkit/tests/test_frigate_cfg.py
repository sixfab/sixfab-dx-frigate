import sys, pathlib
import pytest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import frigate_cfg as fc

FRAG = {
    "models": [{"scene": "outdoor", "path": "/config/model_cache/sq.dxnn"}],
    "cameras": {"garden": {
        "ffmpeg": {"inputs": [{"path": "rtsp://x/y", "roles": ["detect"]}]},
        "detect": {"enabled": True, "scene": "outdoor"},
    }},
}


def test_broker_host():
    assert fc.broker_host({"mqtt": {"host": "10.0.0.5"}}) == "10.0.0.5"
    assert fc.broker_host({}) is None


def test_scene_free_on_empty_config():
    fc.check_scene_slot({}, FRAG)  # no models key at all: must not raise


def test_scene_taken_by_other_model_is_refused():
    cfg = {"models": [{"scene": "outdoor", "path": "/config/model_cache/other.dxnn"}]}
    with pytest.raises(fc.ConfigError, match="outdoor"):
        fc.check_scene_slot(cfg, FRAG)


def test_scene_taken_by_same_model_is_ok():
    cfg = {"models": [{"scene": "outdoor", "path": "/config/model_cache/sq.dxnn"}]}
    fc.check_scene_slot(cfg, FRAG)


def test_check_names_rejects_bad_name():
    with pytest.raises(fc.ConfigError, match="Garden Cam"):
        fc.check_names({}, "outdoor", ["Garden Cam"])


def test_check_names_refuses_other_apps_camera():
    cfg = {"cameras": {"porch": {"detect": {"scene": "indoor"}}}}
    with pytest.raises(fc.ConfigError, match="porch"):
        fc.check_names(cfg, "outdoor", ["porch"])


def test_check_names_allows_own_camera():
    cfg = {"cameras": {"garden": {"detect": {"scene": "outdoor"}}}}
    fc.check_names(cfg, "outdoor", ["garden"])


def test_clone_makes_one_camera_per_pair_and_leaves_template_alone():
    out = fc.clone_cameras(FRAG, [("a", "rtsp://h/1"), ("b", "rtsp://h/2")])
    assert list(out["cameras"]) == ["a", "b"]
    assert out["cameras"]["b"]["ffmpeg"]["inputs"][0]["path"] == "rtsp://h/2"
    assert FRAG["cameras"]["garden"]["ffmpeg"]["inputs"][0]["path"] == "rtsp://x/y"
    assert out["models"] == FRAG["models"]


def test_clone_keeps_special_chars(tmp_path):
    url = "rtsp://user:p&ss#w@rd%20x@10.0.0.9:554/s tream?a=1&b=2"
    out = fc.clone_cameras(FRAG, [("cam1", url)])
    p = tmp_path / "o.yaml"
    fc.dump(out, str(p))
    assert fc.load(str(p))["cameras"]["cam1"]["ffmpeg"]["inputs"][0]["path"] == url


def test_list_and_remove_cameras():
    cfg = {"cameras": {"a": {"detect": {"scene": "outdoor"}}, "b": {"detect": {"scene": "indoor"}}}}
    assert fc.list_cameras(cfg, "outdoor") == ["a"]
    assert "a" not in fc.remove_camera(cfg, "a")["cameras"]
    with pytest.raises(fc.ConfigError):
        fc.remove_camera(cfg, "zzz")


def test_expand_species_sets_track_and_filters():
    out = fc.expand_species(FRAG, ["Yellow Warbler", "Blue Jay"])
    obj = out["cameras"]["garden"]["objects"]
    assert obj["track"] == ["Yellow Warbler", "Blue Jay"]
    assert obj["filters"]["Blue Jay"] == {"min_score": 0.3, "threshold": 0.4}


def test_disable_classifiers():
    cfg = {"classification": {"bird": {"enabled": True},
                              "custom": {"x": {"enabled": True}, "y": {"enabled": False}}}}
    assert fc.disable_classifiers(cfg) is True
    assert cfg["classification"]["bird"]["enabled"] is False
    assert cfg["classification"]["custom"]["x"]["enabled"] is False
    assert fc.disable_classifiers(cfg) is False


def test_same_model_path_under_other_scene_is_refused():
    cfg = {"models": [{"scene": "all", "path": "/config/model_cache/sq.dxnn"}]}
    with pytest.raises(fc.ConfigError, match="sq.dxnn"):
        fc.check_scene_slot(cfg, FRAG)
