# ==========================================
# DIFFICULTY LIMITS
# ==========================================

MIN_DIFFICULTY = 1
MAX_DIFFICULTY = 5


# ==========================================
# PERFORMANCE WEIGHTS
# ==========================================

ACCURACY_WEIGHT = 0.60
REACTION_WEIGHT = 0.25
HINT_WEIGHT = 0.15


# ==========================================
# NORMALIZE ACCURACY
# ==========================================

def normalize_accuracy(accuracy: float) -> float:
    """
    Convert accuracy to a 0-100 scale.

    Supports both:
        0.0 - 1.0
    and:
        0 - 100
    """

    accuracy = float(accuracy)

    if 0 <= accuracy <= 1:
        accuracy *= 100

    return max(0.0, min(100.0, accuracy))


# ==========================================
# CALCULATE REACTION SCORE
# ==========================================

def calculate_reaction_score(
    reaction_time: float,
) -> float:
    """
    Convert reaction time into a 0-100 score.

    Lower reaction time = better performance.
    """

    reaction_time = max(0.0, float(reaction_time))

    if reaction_time <= 5:
        return 100

    if reaction_time <= 10:
        return 90

    if reaction_time <= 15:
        return 80

    if reaction_time <= 20:
        return 70

    if reaction_time <= 30:
        return 60

    return 40


# ==========================================
# CALCULATE HINT SCORE
# ==========================================

def calculate_hint_score(
    hints_used: int,
) -> float:
    """
    Convert hint usage into a 0-100 score.

    Fewer hints = better independence.
    """

    hints_used = max(0, int(hints_used))

    penalty = hints_used * 10

    return max(
        0.0,
        100.0 - penalty
    )


# ==========================================
# CALCULATE PERFORMANCE SCORE
# ==========================================

def calculate_performance_score(
    accuracy: float,
    reaction_time: float,
    hints_used: int,
) -> float:
    """
    Calculate an overall performance score.

    Components:

        Accuracy       -> 60%
        Reaction time  -> 25%
        Hint usage     -> 15%

    Final score is between 0 and 100.
    """

    # --------------------------------------
    # Accuracy
    # --------------------------------------

    accuracy_score = normalize_accuracy(
        accuracy
    )

    # --------------------------------------
    # Reaction time
    # --------------------------------------

    reaction_score = calculate_reaction_score(
        reaction_time
    )

    # --------------------------------------
    # Hint usage
    # --------------------------------------

    hint_score = calculate_hint_score(
        hints_used
    )

    # --------------------------------------
    # Weighted performance
    # --------------------------------------

    performance_score = (
        accuracy_score * ACCURACY_WEIGHT
        + reaction_score * REACTION_WEIGHT
        + hint_score * HINT_WEIGHT
    )

    # --------------------------------------
    # Safety bounds
    # --------------------------------------

    performance_score = max(
        0.0,
        min(100.0, performance_score)
    )

    return round(
        performance_score,
        2
    )


# ==========================================
# RECOMMEND NEXT DIFFICULTY
# ==========================================

def recommend_difficulty(
    current_difficulty: int,
    performance_score: float,
) -> int:
    """
    Recommend the next difficulty level.

    Score >= 85:
        Increase difficulty.

    Score < 50:
        Decrease difficulty.

    Otherwise:
        Keep difficulty unchanged.
    """

    current_difficulty = int(
        current_difficulty
    )

    current_difficulty = max(
        MIN_DIFFICULTY,
        min(
            MAX_DIFFICULTY,
            current_difficulty,
        ),
    )

    performance_score = float(
        performance_score
    )

    if performance_score >= 85:

        return min(
            current_difficulty + 1,
            MAX_DIFFICULTY,
        )

    if performance_score < 50:

        return max(
            current_difficulty - 1,
            MIN_DIFFICULTY,
        )

    return current_difficulty


# ==========================================
# STABLE DIFFICULTY RECOMMENDATION
# ==========================================

def recommend_stable_difficulty(
    current_difficulty: int,
    recent_scores: list[float],
    minimum_attempts: int = 3,
) -> int:
    """
    Recommend difficulty using recent performance.

    We use multiple recent attempts instead of
    changing difficulty based on a single round.

    This makes the system more stable.
    """

    current_difficulty = max(
        MIN_DIFFICULTY,
        min(
            MAX_DIFFICULTY,
            int(current_difficulty),
        ),
    )

    if len(recent_scores) < minimum_attempts:
        return current_difficulty

    recent_scores = [
        max(
            0.0,
            min(100.0, float(score))
        )
        for score in recent_scores[-minimum_attempts:]
    ]

    average_score = sum(
        recent_scores
    ) / len(recent_scores)

    # --------------------------------------
    # Consistently strong
    # --------------------------------------

    if average_score >= 85:

        return min(
            current_difficulty + 1,
            MAX_DIFFICULTY,
        )

    # --------------------------------------
    # Consistently struggling
    # --------------------------------------

    if average_score < 50:

        return max(
            current_difficulty - 1,
            MIN_DIFFICULTY,
        )

    # --------------------------------------
    # Stable performance
    # --------------------------------------

    return current_difficulty