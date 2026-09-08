"""
ML Context Classification for dementia assistance.

Predicts the most likely journey context state and
assistance probability from patient interaction signals.

COLD START: When insufficient data exists, falls back
to the deterministic context engine. ML is never a dependency.
"""

from __future__ import annotations

import json
import math
import os
from typing import Any

import joblib
import numpy as np
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.model_selection import cross_val_score

MODEL_PATH = os.path.join(os.path.dirname(__file__), "..", "ml_models", "context_classifier.joblib")
MIN_TRAINING_SAMPLES = 30
CONTEXT_STATES = ["TRAVELLING", "APPROACHING", "ARRIVED", "TASK_IN_PROGRESS", "POSSIBLY_CONFUSED", "COMPLETED"]
FEATURE_NAMES = [
    "distance_to_destination_m",
    "gps_accuracy",
    "time_elapsed_minutes",
    "distance_change_m",
    "time_since_last_location_s",
    "state_travelling",
    "state_approaching",
    "state_arrived",
    "task_steps_remaining",
    "interaction_count_recent",
    "why_am_i_here_count",
    "im_confused_count",
    "hour_of_day",
]


def extract_features(
    context: dict[str, Any],
    interactions: list[dict] | None = None,
) -> list[float]:
    """
    Extract numeric features from context + interactions.

    Returns a fixed-length feature vector matching FEATURE_NAMES.
    """

    loc = context.get("location", {})
    journey = context.get("journey", {})
    task = context.get("task", {})
    dest = context.get("destination", {})

    distance = loc.get("distance_to_destination_m") or 99999.0
    gps_acc = loc.get("gps_accuracy") or 100.0

    started = journey.get("started_at")
    time_elapsed = 0.0
    if started:
        try:
            from datetime import datetime
            if isinstance(started, str):
                start_dt = datetime.fromisoformat(started.replace("Z", "+00:00"))
            else:
                start_dt = started
            time_elapsed = (datetime.now(start_dt.tzinfo) - start_dt).total_seconds() / 60.0
        except Exception:
            time_elapsed = 0.0

    state = journey.get("state", "TRAVELLING")

    interactions = interactions or []
    recent_count = sum(1 for i in interactions if _is_recent(i, minutes=30))
    why_count = sum(1 for i in interactions if i.get("interaction_type") == "WHY_AM_I_HERE")
    confused_count = sum(1 for i in interactions if i.get("interaction_type") == "IM_CONFUSED")

    dist_change = 0.0
    if len(interactions) >= 2:
        prev = interactions[-2]
        curr = interactions[-1]
        p_lat = prev.get("latitude")
        p_lng = prev.get("longitude")
        c_lat = curr.get("latitude")
        c_lng = curr.get("longitude")
        if all(v is not None for v in [p_lat, p_lng, c_lat, c_lng]):
            dist_change = _haversine_m(p_lat, p_lng, c_lat, c_lng)

    time_since_last = 0.0
    if interactions:
        last = interactions[-1]
        last_ts = last.get("timestamp")
        if last_ts:
            try:
                from datetime import datetime
                if isinstance(last_ts, str):
                    last_dt = datetime.fromisoformat(last_ts.replace("Z", "+00:00"))
                else:
                    last_dt = last_ts
                time_since_last = (datetime.now(last_dt.tzinfo) - last_dt).total_seconds()
            except Exception:
                time_since_last = 0.0

    try:
        from datetime import datetime
        hour = datetime.now().hour
    except Exception:
        hour = 12

    return [
        float(distance),
        float(gps_acc),
        float(time_elapsed),
        float(dist_change),
        float(time_since_last),
        1.0 if state == "TRAVELLING" else 0.0,
        1.0 if state == "APPROACHING" else 0.0,
        1.0 if state == "ARRIVED" else 0.0,
        float(task.get("steps_remaining", 0)),
        float(recent_count),
        float(why_count),
        float(confused_count),
        float(hour),
    ]


def predict_state(
    features: list[float],
    interactions: list[dict] | None = None,
) -> dict[str, Any]:
    """
    Predict context state using ML if available,
    otherwise fall back to deterministic rules.

    Returns:
        {
            "predicted_state": "ARRIVED",
            "method": "ml" | "rule_based",
            "assistance_probability": 0.23,
            "model_available": True | False,
        }
    """

    model = _load_model()

    if model is None:
        result = _rule_based_predict(features)
        result["method"] = "rule_based"
        result["model_available"] = False
        return result

    try:
        X = np.array([features])
        predicted_idx = int(model.predict(X)[0])
        predicted_state = CONTEXT_STATES[predicted_idx]

        proba = model.predict_proba(X)[0]
        assistance_idx = CONTEXT_STATES.index("POSSIBLY_CONFUSED")
        assistance_prob = float(proba[assistance_idx])

        return {
            "predicted_state": predicted_state,
            "method": "ml",
            "assistance_probability": round(assistance_prob, 3),
            "model_available": True,
            "confidence": round(float(max(proba)), 3),
        }
    except Exception:
        result = _rule_based_predict(features)
        result["method"] = "rule_based_fallback"
        result["model_available"] = False
        return result


def _rule_based_predict(features: list[float]) -> dict[str, Any]:
    """
    Deterministic rule-based prediction when ML is unavailable.
    """

    distance = features[0]
    gps_acc = features[1]
    time_elapsed = features[2]
    state_travelling = features[5]
    state_approaching = features[6]
    state_arrived = features[7]
    steps_remaining = features[8]
    why_count = features[10]
    confused_count = features[11]

    if state_arrived > 0.5:
        if steps_remaining > 0:
            state = "TASK_IN_PROGRESS"
        else:
            state = "ARRIVED"
    elif state_approaching > 0.5:
        state = "APPROACHING"
    else:
        state = "TRAVELLING"

    assistance_prob = 0.05

    if confused_count > 2:
        assistance_prob = 0.9
    elif why_count > 3:
        assistance_prob = 0.7
    elif time_elapsed > 60 and state != "COMPLETED":
        assistance_prob = 0.5
    elif distance < 100 and state_travelling > 0.5:
        assistance_prob = 0.3

    return {
        "predicted_state": state,
        "assistance_probability": round(min(assistance_prob, 1.0), 3),
        "confidence": 0.7,
    }


def train_model(
    training_data: list[dict],
) -> dict[str, Any]:
    """
    Train the context classifier on historical interaction data.

    Each training sample should have:
    - features: list[float]
    - label: int (index into CONTEXT_STATES)

    Returns training metrics.
    """

    if len(training_data) < MIN_TRAINING_SAMPLES:
        return {
            "status": "insufficient_data",
            "samples": len(training_data),
            "required": MIN_TRAINING_SAMPLES,
        }

    X = np.array([d["features"] for d in training_data])
    y = np.array([d["label"] for d in training_data])

    unique_classes = np.unique(y)
    if len(unique_classes) < 2:
        return {
            "status": "insufficient_classes",
            "classes": len(unique_classes),
        }

    model = GradientBoostingClassifier(
        n_estimators=50,
        max_depth=4,
        random_state=42,
    )

    cv_folds = min(5, len(unique_classes))
    scores = cross_val_score(model, X, y, cv=cv_folds, scoring="accuracy")

    model.fit(X, y)

    os.makedirs(os.path.dirname(MODEL_PATH), exist_ok=True)
    joblib.dump(model, MODEL_PATH)

    return {
        "status": "trained",
        "samples": len(training_data),
        "accuracy_mean": round(float(scores.mean()), 3),
        "accuracy_std": round(float(scores.std()), 3),
        "model_path": MODEL_PATH,
    }


def _load_model():
    """Load the saved ML model if available."""

    if not os.path.exists(MODEL_PATH):
        return None

    try:
        return joblib.load(MODEL_PATH)
    except Exception:
        return None


def _haversine_m(lat1, lon1, lat2, lon2):
    R = 6_371_000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _is_recent(interaction: dict, minutes: int = 30) -> bool:
    try:
        from datetime import datetime, timedelta
        ts = interaction.get("timestamp")
        if ts is None:
            return False
        if isinstance(ts, str):
            dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        else:
            dt = ts
        return (datetime.now(dt.tzinfo) - dt) < timedelta(minutes=minutes)
    except Exception:
        return False
