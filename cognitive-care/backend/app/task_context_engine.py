"""
Deterministic Task Context Engine for dementia assistance.

This module builds a structured TaskContext from journey data,
GPS location, and patient interactions.

It NEVER invents information. It only uses trusted data
provided by the caregiver or stored in the journey record.
"""

from __future__ import annotations

import math
from datetime import datetime, timezone
from typing import Any


# ============================================================
# DISTANCE THRESHOLDS (configurable)
# ============================================================

APPROACHING_DISTANCE_M = 500
ARRIVED_DISTANCE_M = 100
INSIDE_DISTANCE_M = 30
GPS_ACCURACY_THRESHOLD_M = 50


# ============================================================
# TASK CONTEXT BUILDER
# ============================================================


def build_task_context(
    journey: dict[str, Any],
    current_latitude: float | None = None,
    current_longitude: float | None = None,
    gps_accuracy: float | None = None,
    recent_interactions: list[dict] | None = None,
) -> dict[str, Any]:
    """
    Build a structured TaskContext from trusted journey data.

    Returns a context dictionary with these sections:
    - location: current GPS, distance, accuracy
    - destination: name, coordinates, address
    - task: purpose, instruction, steps, current step
    - journey: state, timestamps
    - assistance: what the system knows and can say
    """

    dest_lat = journey.get("destination_latitude", 0)
    dest_lng = journey.get("destination_longitude", 0)
    dest_name = journey.get("destination_name", "your destination")
    purpose = journey.get("purpose", "")
    instruction = journey.get("instruction", "")
    status = journey.get("status", "active")
    steps = journey.get("steps", [])
    current_step = journey.get("current_step", 0)

    distance_m = None
    if current_latitude is not None and current_longitude is not None:
        distance_m = _haversine_m(
            current_latitude, current_longitude,
            dest_lat, dest_lng,
        )
    elif journey.get("distance_to_destination_m") is not None:
        distance_m = journey["distance_to_destination_m"]

    journey_state = _derive_journey_state(
        status=status,
        distance_m=distance_m,
        gps_accuracy=gps_accuracy,
    )

    step_info = _get_step_info(steps, current_step)

    assistance = _build_assistance_hints(
        dest_name=dest_name,
        purpose=purpose,
        instruction=instruction,
        journey_state=journey_state,
        step_info=step_info,
        distance_m=distance_m,
        gps_accuracy=gps_accuracy,
    )

    return {
        "location": {
            "latitude": current_latitude,
            "longitude": current_longitude,
            "distance_to_destination_m": distance_m,
            "gps_accuracy": gps_accuracy,
            "gps_reliable": _gps_is_reliable(gps_accuracy),
        },
        "destination": {
            "name": dest_name,
            "latitude": dest_lat,
            "longitude": dest_lng,
            "address": journey.get("destination_address", ""),
        },
        "task": {
            "purpose": purpose,
            "instruction": instruction,
            "steps": steps,
            "current_step": current_step,
            "current_step_text": step_info.get("text", ""),
            "next_step_text": step_info.get("next", ""),
            "total_steps": len(steps),
            "steps_remaining": max(0, len(steps) - current_step),
        },
        "journey": {
            "id": str(journey.get("_id", "")),
            "state": journey_state,
            "status": status,
            "started_at": _iso(journey.get("started_at")),
            "arrival_at": _iso(journey.get("arrival_at")),
            "expected_duration_minutes": journey.get("expected_duration_minutes", 45),
        },
        "assistance": assistance,
        "confidence": _calculate_confidence(
            distance_m=distance_m,
            gps_accuracy=gps_accuracy,
            has_purpose=bool(purpose),
            has_steps=bool(steps),
        ),
    }


# ============================================================
# JOURNEY STATE DERIVATION
# ============================================================


def _derive_journey_state(
    status: str,
    distance_m: float | None,
    gps_accuracy: float | None = None,
) -> str:
    """
    Derive a deterministic journey state from status + distance.

    States:
    - PLANNED
    - TRAVELLING
    - APPROACHING
    - ARRIVED
    - TASK_IN_PROGRESS
    - COMPLETED
    - CANCELLED
    """

    if status in ("completed",):
        return "COMPLETED"
    if status in ("cancelled",):
        return "CANCELLED"
    if status in ("arrived",):
        return "ARRIVED"

    if distance_m is None:
        return "TRAVELLING"

    if distance_m <= INSIDE_DISTANCE_M:
        return "ARRIVED"
    if distance_m <= APPROACHING_DISTANCE_M:
        return "APPROACHING"
    return "TRAVELLING"


# ============================================================
# STEP INFO
# ============================================================


def _get_step_info(
    steps: list[str],
    current_step: int,
) -> dict[str, str]:
    """Return current step text and next step text."""

    if not steps:
        return {"text": "", "next": ""}

    idx = max(0, min(current_step, len(steps) - 1))

    result: dict[str, str] = {
        "text": steps[idx],
        "next": "",
    }

    if idx + 1 < len(steps):
        result["next"] = steps[idx + 1]

    return result


# ============================================================
# ASSISTANCE HINTS
# ============================================================


def _build_assistance_hints(
    dest_name: str,
    purpose: str,
    instruction: str,
    journey_state: str,
    step_info: dict[str, str],
    distance_m: float | None,
    gps_accuracy: float | None,
) -> dict[str, Any]:
    """
    Build structured assistance information.

    This is what the response generator and Flutter UI consume.
    """

    hints: dict[str, Any] = {
        "can_explain_purpose": bool(purpose),
        "can_explain_destination": bool(dest_name),
        "can_explain_next_step": bool(step_info.get("next")),
        "should_speak_on_arrival": journey_state == "ARRIVED",
        "should_offer_help": journey_state in ("ARRIVED", "APPROACHING"),
        "has_indoor_directions": bool(step_info.get("next")),
    }

    return hints


# ============================================================
# CONFIDENCE
# ============================================================


def _calculate_confidence(
    distance_m: float | None,
    gps_accuracy: float | None,
    has_purpose: bool,
    has_steps: bool,
) -> float:
    """
    Calculate a confidence score (0.0 - 1.0) for the context.

    Higher = more reliable context.
    """

    confidence = 0.5

    if has_purpose:
        confidence += 0.25
    if has_steps:
        confidence += 0.1
    if distance_m is not None:
        if distance_m <= ARRIVED_DISTANCE_M:
            confidence += 0.15
        elif distance_m <= APPROACHING_DISTANCE_M:
            confidence += 0.1
        else:
            confidence += 0.05
    if gps_accuracy is not None and gps_accuracy < GPS_ACCURACY_THRESHOLD_M:
        confidence += 0.05

    return round(min(confidence, 1.0), 2)


# ============================================================
# HELPERS
# ============================================================


def _haversine_m(
    lat1: float, lon1: float,
    lat2: float, lon2: float,
) -> float:
    """Distance in metres between two lat/lng points."""

    R = 6_371_000
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)

    a = (
        math.sin(dphi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2)
        * math.sin(dlam / 2) ** 2
    )
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _gps_is_reliable(accuracy: float | None) -> bool:
    """Check if GPS accuracy is reliable enough."""

    if accuracy is None:
        return False
    return accuracy <= GPS_ACCURACY_THRESHOLD_M


def _iso(dt: datetime | None) -> str | None:
    """Convert datetime to ISO string."""

    if dt is None:
        return None
    if isinstance(dt, str):
        return dt
    return dt.isoformat()
