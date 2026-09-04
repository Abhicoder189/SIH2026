from .adaptation import (
    MIN_DIFFICULTY,
    MAX_DIFFICULTY,
    recommend_stable_difficulty,
)


# ==========================================
# GAME TYPE SELECTION
# ==========================================

def select_game_type(
    average_performance_score: float,
):
    """
    Select the cognitive game type based on
    the patient's recent overall performance.

    This is a personalization rule, not a
    medical diagnosis.
    """

    if average_performance_score < 50:
        return {
            "game_type": "memory",
            "reason": (
                "Performance is low, so a simpler "
                "memory exercise is recommended."
            ),
        }

    if average_performance_score < 70:
        return {
            "game_type": "memory",
            "reason": (
                "Moderate performance detected, so "
                "memory training is recommended."
            ),
        }

    if average_performance_score < 85:
        return {
            "game_type": "attention",
            "reason": (
                "Performance is good, so attention "
                "training can be introduced."
            ),
        }

    return {
        "game_type": "pattern",
        "reason": (
            "Strong performance detected, so a more "
            "challenging pattern exercise is recommended."
        ),
    }


# ==========================================
# EXTRACT RECENT PERFORMANCE
# ==========================================

def get_recent_scores(
    analytics: dict,
) -> list[float]:
    """
    Extract recent performance scores.

    The analytics dictionary may contain
    recent attempts under 'recent_attempts'.

    If unavailable, return an empty list.
    """

    recent_attempts = analytics.get(
        "recent_attempts",
        [],
    )

    scores = []

    for attempt in recent_attempts:

        score = attempt.get(
            "performance_score"
        )

        if score is not None:

            try:
                scores.append(
                    float(score)
                )

            except (
                TypeError,
                ValueError,
            ):
                continue

    return scores


# ==========================================
# RECOMMEND SESSION
# ==========================================

def recommend_session(
    analytics: dict,
):
    """
    Recommend the next cognitive-game session.

    Uses:

        1. Previous performance
        2. Recent performance stability
        3. Current difficulty
        4. Overall trend

    This function personalizes the session.
    It does not diagnose or predict a medical
    condition.
    """

    total_attempts = int(
        analytics.get(
            "total_attempts",
            0,
        )
    )

    average_performance_score = float(
        analytics.get(
            "average_performance_score",
            0,
        )
        or 0
    )

    current_difficulty = analytics.get(
        "current_difficulty"
    )

    trend = analytics.get(
        "trend",
        "insufficient_data",
    )

    # ======================================
    # FIRST SESSION
    # ======================================

    if total_attempts == 0:

        return {
            "game_type": "memory",
            "difficulty": MIN_DIFFICULTY,
            "reason": (
                "No previous game data is available. "
                "Starting with an easy memory exercise."
            ),
            "trend": "insufficient_data",
            "method": "rule_based",
        }

    # ======================================
    # GAME SELECTION
    # ======================================

    game_selection = select_game_type(
        average_performance_score
    )

    # ======================================
    # CURRENT DIFFICULTY
    # ======================================

    if current_difficulty is None:

        current_difficulty = MIN_DIFFICULTY

    try:

        current_difficulty = int(
            current_difficulty
        )

    except (
        TypeError,
        ValueError,
    ):

        current_difficulty = MIN_DIFFICULTY

    current_difficulty = max(
        MIN_DIFFICULTY,
        min(
            MAX_DIFFICULTY,
            current_difficulty,
        ),
    )

    # ======================================
    # RECENT PERFORMANCE
    # ======================================

    recent_scores = get_recent_scores(
        analytics
    )

    # ======================================
    # STABLE DIFFICULTY
    # ======================================

    difficulty = recommend_stable_difficulty(
        current_difficulty=current_difficulty,
        recent_scores=recent_scores,
        minimum_attempts=3,
    )

    # ======================================
    # SAFETY CHECK FOR DECLINING TREND
    # ======================================

    if trend == "declining":

        difficulty = max(
            MIN_DIFFICULTY,
            difficulty - 1,
        )

    # ======================================
    # SAFETY CHECK FOR INSUFFICIENT DATA
    # ======================================

    if len(recent_scores) < 3:

        difficulty = current_difficulty

    # ======================================
    # FINAL RESPONSE
    # ======================================

    return {
        "game_type": game_selection[
            "game_type"
        ],

        "difficulty": difficulty,

        "reason": game_selection[
            "reason"
        ],

        "trend": trend,

        "recent_scores": recent_scores[
            -3:
        ],

        "method": "rule_based",
    }