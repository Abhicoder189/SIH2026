"""
ML personalization layer.

Uses historical game attempts to recommend the next game difficulty.

IMPORTANT:
This model personalizes gameplay only.
It does NOT diagnose dementia or predict medical conditions.
"""

from __future__ import annotations

from collections import Counter
from typing import Any

try:
    from sklearn.ensemble import RandomForestClassifier
except Exception:  # pragma: no cover
    RandomForestClassifier = None


GAME_TYPES = {
    "memory": 1,
    "attention": 2,
    "pattern": 3,
}


def _game_type_value(attempt: dict) -> float:
    """
    Convert game type into a simple numeric feature.
    """

    game_type = str(
        attempt.get("game_type", "")
    ).lower().strip()

    return float(
        GAME_TYPES.get(game_type, 0)
    )


def _features(attempt: dict) -> list[float]:
    """
    Build ML features from one attempt.
    """

    accuracy = float(
        attempt.get("accuracy", 0) or 0
    )

    if accuracy <= 1:
        accuracy *= 100

    reaction = float(
        attempt.get("reaction_time", 0) or 0
    )

    hints = float(
        attempt.get("hints_used", 0) or 0
    )

    score = float(
        attempt.get("performance_score", 0) or 0
    )

    difficulty = float(
        attempt.get("difficulty", 1) or 1
    )

    game_type = _game_type_value(attempt)

    return [
        accuracy,
        reaction,
        hints,
        score,
        difficulty,
        game_type,
    ]


def _label(attempt: dict) -> int | None:
    """
    Extract the target difficulty.
    """

    value = attempt.get("next_difficulty")

    try:
        value = int(value)
    except (TypeError, ValueError):
        return None

    if 1 <= value <= 5:
        return value

    return None


def _rule_based_result(
    fallback: int,
) -> dict[str, Any]:
    """
    Safe fallback when ML cannot be used.
    """

    fallback = max(
        1,
        min(5, int(fallback)),
    )

    return {
        "difficulty": fallback,
        "method": "rule_based",
        "confidence": None,
        "training_samples": 0,
        "classes": [],
    }


def ml_recommend_difficulty(
    attempts: list[dict],
    fallback: int,
) -> dict[str, Any]:
    """
    Recommend the next difficulty.

    ML is used only when enough historical data exists
    and the training data contains multiple classes.
    """

    fallback = max(
        1,
        min(5, int(fallback)),
    )

    if RandomForestClassifier is None:
        return _rule_based_result(fallback)

    rows: list[list[float]] = []
    labels: list[int] = []

    for attempt in attempts:

        label = _label(attempt)

        if label is None:
            continue

        rows.append(
            _features(attempt)
        )

        labels.append(label)

    # We need enough examples to avoid an unstable model.
    if len(rows) < 10:
        return _rule_based_result(fallback)

    # Classification requires at least two classes.
    if len(set(labels)) < 2:
        return _rule_based_result(fallback)

    model = RandomForestClassifier(
        n_estimators=100,
        max_depth=6,
        min_samples_leaf=2,
        random_state=42,
        class_weight="balanced",
    )

    model.fit(
        rows,
        labels,
    )

    if not attempts:
        return _rule_based_result(fallback)

    latest = attempts[-1]

    probabilities = model.predict_proba(
        [_features(latest)]
    )[0]

    prediction = int(
        model.predict(
            [_features(latest)]
        )[0]
    )

    confidence = round(
        float(max(probabilities)) * 100,
        1,
    )

    return {
        "difficulty": max(
            1,
            min(5, prediction),
        ),
        "method": "ml_random_forest",
        "confidence": confidence,
        "training_samples": len(rows),
        "classes": sorted(
            Counter(labels)
        ),
    }