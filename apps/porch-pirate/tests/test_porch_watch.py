import importlib, json, sys, types, pathlib

APP_DIR = pathlib.Path(__file__).resolve().parents[1]
TOOLKIT_DIR = pathlib.Path(__file__).resolve().parents[3] / "toolkit"


def load_module():
    paho = types.ModuleType("paho"); mqtt = types.ModuleType("paho.mqtt")
    client = types.ModuleType("paho.mqtt.client")
    client.Client = object; client.MQTTMessage = object
    sys.modules.update({"paho": paho, "paho.mqtt": mqtt, "paho.mqtt.client": client})
    paho.mqtt = mqtt; mqtt.client = client
    sys.path.insert(0, str(TOOLKIT_DIR))
    sys.path.insert(0, str(APP_DIR / "automation"))
    sys.modules.pop("porch_watch", None)
    return importlib.import_module("porch_watch")


class Msg:
    def __init__(self, d): self.payload = json.dumps(d).encode()


class Client:
    def __init__(self): self.published = []
    def publish(self, topic, payload, qos=0): self.published.append((topic, json.loads(payload)))


def ev(kind, label, id_, camera, zones=("frontdoor_zone",)):
    return Msg({"type": kind, "after": {"id": id_, "label": label, "camera": camera,
                                        "current_zones": list(zones), "top_score": 0.9}})


def test_other_cameras_person_is_not_secondary():
    pw = load_module(); pw.ALLOWED = None
    c = Client()
    pw.on_message(c, None, ev("new", "person", "p1", "camA"))
    pw.on_message(c, None, ev("new", "package", "box1", "camA"))
    pw.on_message(c, None, ev("new", "person", "p2", "camB"))  # other camera, same zone name
    pw.on_message(c, None, ev("end", "package", "box1", "camA"))
    assert c.published == []


def test_same_camera_second_person_triggers_alert():
    pw = load_module(); pw.ALLOWED = None
    c = Client()
    pw.on_message(c, None, ev("new", "person", "p1", "camA"))
    pw.on_message(c, None, ev("new", "package", "box1", "camA"))
    pw.on_message(c, None, ev("new", "person", "p2", "camA"))
    pw.on_message(c, None, ev("end", "package", "box1", "camA"))
    assert len(c.published) == 1 and c.published[0][1]["suspect_person_id"] == "p2"


def test_camera_not_in_cameras_txt_is_ignored():
    pw = load_module(); pw.ALLOWED = {"camA"}
    c = Client()
    pw.on_message(c, None, ev("new", "person", "p1", "camB"))
    pw.on_message(c, None, ev("new", "package", "box1", "camB"))
    pw.on_message(c, None, ev("new", "person", "p2", "camB"))
    pw.on_message(c, None, ev("end", "package", "box1", "camB"))
    assert c.published == []
