"""Boss Detector - frigate/events listener + MQTT trigger.

Zero custom model: the DEEPX detector already detects the "person" class
(coco-and-cardboxes.dxnn, class 1=person, active on the frontdoor camera).
This script just listens for existing person detections and fires a
trigger - no config change was needed on the Frigate/DEEPX side.

The real action (switch a screen, sound, light) is marked TODO - to be
added based on user preference. For now it just logs (same pattern as
squirrel-sprinkler's trigger_sprinkler() placeholder).
"""

import json
import logging
import time

import paho.mqtt.client as mqtt

try:
    from camera_filter import is_allowed, load_allowed
except ImportError:  # running from the repo tree, not from the installed folder
    import pathlib
    import sys
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / "lib"))
    from camera_filter import is_allowed, load_allowed

ALLOWED = load_allowed()  # None = every camera; cameras.txt next to this script limits it

BROKER = "127.0.0.1"
PORT = 1883
EVENTS_TOPIC = "frigate/events"
ALERT_TOPIC = "boss_detector/alert"
TARGET_LABEL = "person"
MIN_SCORE = 0.6
COOLDOWN_SECONDS = 5  # just to prevent spam - always fires on first sighting

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
log = logging.getLogger("boss-detector")

_last_triggered: dict[str, float] = {}


def trigger_alert(client: mqtt.Client, camera: str, score: float) -> None:
    """Log the alert and publish it to ALERT_TOPIC as JSON.

    TODO: real action goes here.
    Examples: requests.post(webhook_url, json=...), play a sound
    (playsound), trigger a smart plug/light, print "BOSS INCOMING" on a
    receipt printer, publish to Home Assistant via MQTT."""
    log.warning("BOSS DETECTED camera=%s score=%.2f (simulated for now)", camera, score)
    client.publish(
        ALERT_TOPIC,
        json.dumps({"camera": camera, "score": round(score, 2), "timestamp": time.time()}),
        qos=1,
    )


def on_connect(client: mqtt.Client, userdata, flags, rc):
    if rc != 0:
        log.error("MQTT connection error, rc=%s", rc)
        return
    log.info("Connected to broker (%s:%s), listening on %s", BROKER, PORT, EVENTS_TOPIC)
    client.subscribe(EVENTS_TOPIC)


def on_message(client: mqtt.Client, userdata, msg: mqtt.MQTTMessage):
    try:
        payload = json.loads(msg.payload.decode())
    except (json.JSONDecodeError, UnicodeDecodeError):
        log.warning("Malformed payload, skipping")
        return

    after = payload.get("after") or {}
    if not is_allowed(after.get("camera"), ALLOWED):
        return
    event_type = payload.get("type")
    label = after.get("label")

    if label != TARGET_LABEL:
        return

    # Both "new" AND "update" trigger - notified as soon as the person is
    # seen (first "new" event, published ~0.4s in) and again as they move
    # (each "update"). Only cooldown prevents spam, not the event type.
    if event_type not in ("new", "update"):
        return

    camera = after.get("camera")
    score = after.get("top_score") or after.get("score") or 0.0
    if score < MIN_SCORE:
        log.debug("Score below threshold (%.2f < %.2f), skipping", score, MIN_SCORE)
        return

    now = time.monotonic()
    last = _last_triggered.get(camera, 0.0)
    if now - last < COOLDOWN_SECONDS:
        log.info(
            "Person detected again but still in cooldown (%.0fs left), skipping",
            COOLDOWN_SECONDS - (now - last),
        )
        return

    _last_triggered[camera] = now
    trigger_alert(client, camera, score)


def main() -> None:
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(BROKER, PORT, keepalive=60)
    client.loop_forever()


if __name__ == "__main__":
    main()
