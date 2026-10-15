"""Porch Pirate - frigate/events listener + theft-alert logic.

Observability (existing):
  - PERSON_ENTERED_ZONE: a "person" entered frontdoor_zone
  - PACKAGE_DROPPED:     a "package" was seen for the first time (new event)
  - PACKAGE_REMOVED:     a previously-seen "package" event ended

Theft-alert logic:
  A package is associated with a "dropper set" - the track ids of whoever
  is in the zone at the moment the package first appears (the person(s)
  presumed to have dropped it). While the package is still in the zone, if
  a new person (track id NOT in that set) enters the zone, they're flagged
  as "secondary" (unrelated/suspicious) for this package. If the package
  later disappears (event "end") AND a secondary person was seen:
  THEFT_ALERT_SUSPECTED fires (and is published to MQTT, see ALERT_TOPIC
  below). No secondary person means the same person likely picked it back
  up, or nobody else ever showed up - silently logged as PACKAGE_REMOVED,
  the normal case.

  State is kept per camera, so a person on one camera never counts as a
  secondary person for a package on another camera.

  Note: Frigate assigns a NEW track id when the same physical person
  leaves and re-enters the frame (no re-identification). So "different
  person" detection is really "different track id" - the same person
  stepping out of frame and back in can technically count as a "secondary
  person". A real identity check would need a face_recognition sub_label
  comparison.
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
ALERT_TOPIC = "porch_pirate/theft_alert"
ZONE_NAME = "frontdoor_zone"
PACKAGE_LABEL = "package"  # this model's class name (was "cardboard box" on the old model)

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
log = logging.getLogger("porch-pirate")

_zone_entry_logged: set[str] = set()
_persons_in_zone: dict[str, set[str]] = {}  # camera -> active person event_ids inside the zone
_active_boxes: dict[str, dict] = {}  # box_event_id -> {camera, score, dropper_ids, secondary_id}


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
    event_type = payload.get("type")
    event_id = after.get("id")
    label = after.get("label")
    camera = after.get("camera")
    zones = after.get("current_zones") or []
    score = after.get("top_score") or after.get("score") or 0.0
    in_zone = ZONE_NAME in zones

    if not is_allowed(camera, ALLOWED):
        return

    if label == "person":
        persons = _persons_in_zone.setdefault(camera, set())
        if in_zone:
            if event_id not in _zone_entry_logged:
                _zone_entry_logged.add(event_id)
                log.info("PERSON_ENTERED_ZONE camera=%s zone=%s score=%.2f id=%s", camera, ZONE_NAME, score, event_id)
            if event_id not in persons:
                persons.add(event_id)
                # any already-active package that doesn't have this person in its
                # dropper set now has a "secondary" (unrelated) person present
                for box_id, info in _active_boxes.items():
                    if info["camera"] == camera and event_id not in info["dropper_ids"] and info["secondary_id"] is None:
                        info["secondary_id"] = event_id
                        log.info(
                            "SECONDARY_PERSON_NEAR_PACKAGE camera=%s box_id=%s person_id=%s",
                            camera, box_id, event_id,
                        )
        if event_type == "end":
            persons.discard(event_id)
            _zone_entry_logged.discard(event_id)

    if label == PACKAGE_LABEL:
        if event_type == "new" and event_id not in _active_boxes:
            dropper_ids = set(_persons_in_zone.get(camera, set()))
            _active_boxes[event_id] = {
                "camera": camera,
                "score": score,
                "dropper_ids": dropper_ids,
                "secondary_id": None,
            }
            log.info(
                "PACKAGE_DROPPED camera=%s score=%.2f event_id=%s dropper_ids=%s",
                camera, score, event_id, sorted(dropper_ids) or "none-visible",
            )
        elif event_type == "end" and event_id in _active_boxes:
            info = _active_boxes.pop(event_id)
            if info["secondary_id"] is not None:
                log.warning(
                    "THEFT_ALERT_SUSPECTED camera=%s box_id=%s suspect_person_id=%s "
                    "(dropped_by=%s, dropped_score=%.2f)",
                    info["camera"], event_id, info["secondary_id"],
                    sorted(info["dropper_ids"]) or "none-visible", info["score"],
                )
                client.publish(
                    ALERT_TOPIC,
                    json.dumps({
                        "camera": info["camera"],
                        "box_id": event_id,
                        "suspect_person_id": info["secondary_id"],
                        "dropped_by": sorted(info["dropper_ids"]),
                        "dropped_score": info["score"],
                        "timestamp": time.time(),
                    }),
                    qos=1,
                )
            else:
                log.info(
                    "PACKAGE_REMOVED camera=%s event_id=%s (dropped at score=%.2f, no unrelated person seen)",
                    info["camera"], event_id, info["score"],
                )


def main() -> None:
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message
    client.connect(BROKER, PORT, keepalive=60)
    client.loop_forever()


if __name__ == "__main__":
    main()
