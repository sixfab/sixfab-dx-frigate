"""Squirrel Sprinkler - frigate/events listener + sprinkler trigger.

Frigate publishes a JSON payload to the frigate/events topic on every
object event: {"type": "new"|"update"|"end", "before": {...}, "after": {...}}.
Triggers when "after.label" == "Squirrel".

The physical solenoid valve/relay isn't wired up yet - real GPIO/relay
control goes where TRIGGER_CMD is marked (which board it runs on depends
on which board the valve is wired to - for now it just logs).

Cooldown: a per-camera COOLDOWN_SECONDS wait prevents continuously
triggering (continuously spraying water) for a squirrel sitting still in
the same spot in the yard.
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
TRIGGER_TOPIC = "squirrel_sprinkler/trigger"
TARGET_LABEL = "Squirrel"
MIN_SCORE = 0.6
COOLDOWN_SECONDS = 30

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
log = logging.getLogger("squirrel-sprinkler")

_last_triggered: dict[str, float] = {}
_seen_event_types: dict[str, str] = {}


def trigger_sprinkler(client: mqtt.Client, camera: str, score: float) -> None:
    """Log the trigger and publish it to TRIGGER_TOPIC as JSON.

    TODO: real relay/solenoid valve trigger goes here.
    E.g. GPIO.output(RELAY_PIN, GPIO.HIGH); time.sleep(2); GPIO.output(RELAY_PIN, GPIO.LOW)
    or a request to a Sixfab/relay HAT's REST/MQTT interface."""
    log.info("SPRINKLER TRIGGER camera=%s score=%.2f (simulated for now)", camera, score)
    client.publish(
        TRIGGER_TOPIC,
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
    event_id = after.get("id")
    label = after.get("label")

    if label != TARGET_LABEL:
        return

    if event_type != "new" or _seen_event_types.get(event_id) == "new":
        _seen_event_types[event_id] = event_type
        return
    _seen_event_types[event_id] = event_type

    camera = after.get("camera")
    score = after.get("top_score") or after.get("score") or 0.0
    if score < MIN_SCORE:
        log.debug("Score below threshold (%.2f < %.2f), skipping", score, MIN_SCORE)
        return

    now = time.monotonic()
    last = _last_triggered.get(camera, 0.0)
    if now - last < COOLDOWN_SECONDS:
        log.info(
            "Squirrel detected again but still in cooldown (%.0fs left), skipping",
            COOLDOWN_SECONDS - (now - last),
        )
        return

    _last_triggered[camera] = now
    trigger_sprinkler(client, camera, score)


def main() -> None:
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(BROKER, PORT, keepalive=60)
    client.loop_forever()


if __name__ == "__main__":
    main()
