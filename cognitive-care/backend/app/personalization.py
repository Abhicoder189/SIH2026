from .adaptation import (
    MIN_DIFFICULTY,
    MAX_DIFFICULTY,
    recommend_stable_difficulty,
)


GAME_TYPES = (
    "memory",
    "attention",
    "pattern",
)


def _safe_float(value, default=0.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _safe_int(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def get_recent_attempts(
    analytics: dict,
) -> list[dict]:
    """
    Return recent attempts supplied by analytics.

    The analytics layer may provide recent_attempts.
    Missing or malformed data is safely ignored.
    """
    attempts = analytics.get("recent_attempts", [])

    if not isinstance(attempts, list):
        return []

    return [
        attempt
        for attempt in attempts
        if isinstance(attempt, dict)
    ]


def get_recent_scores(
    analytics: dict,
) -> list[float]:
    """Extract recent performance scores."""
    scores = []

    for attempt in get_recent_attempts(analytics):
        score = attempt.get("performance_score")

        if score is None:
            continue

        try:
            scores.append(float(score))
        except (TypeError, ValueError):
            continue

    return scores


def _game_statistics(
    attempts: list[dict],
) -> dict[str, dict]:
    """
    Calculate simple per-game statistics.

    This prevents the recommendation from relying only
    on the patient's global average.
    """
    statistics = {
        game_type: {
            "count": 0,
            "scores": [],
            "average": 0.0,
        }
        for game_type in GAME_TYPES
    }

    for attempt in attempts:
        game_type = str(
            attempt.get("game_type", "")
        ).lower()

        if game_type not in statistics:
            continue

        score = attempt.get("performance_score")

        if score is None:
            continue

        try:
            score = float(score)
        except (TypeError, ValueError):
            continue

        statistics[game_type]["count"] += 1
        statistics[game_type]["scores"].append(score)

    for game_type in GAME_TYPES:
        scores = statistics[game_type]["scores"]

        if scores:
            statistics[game_type]["average"] = (
                sum(scores) / len(scores)
            )

    return statistics


def select_game_type(
    average_performance_score: float,
    recent_attempts: list[dict],
) -> tuple[str, str]:
    """
    Select the next game using:

    1. Overall performance
    2. Game-specific performance
    3. Recent game variety

    This is personalization, not medical diagnosis.
    """
    statistics = _game_statistics(recent_attempts)

    recent_game_types = [
        str(attempt.get("game_type", "")).lower()
        for attempt in recent_attempts
        if str(attempt.get("game_type", "")).lower()
        in GAME_TYPES
    ]

    # If every game has been played, prefer the least recently
    # used game to provide balanced cognitive engagement.
    if len(set(recent_game_types)) == len(GAME_TYPES):
        for game_type in GAME_TYPES:
            if recent_game_types[-1:] != [game_type]:
                break

    # Prioritize games with weak performance when enough data exists.
    games_with_data = [
        game_type
        for game_type in GAME_TYPES
        if statistics[game_type]["count"] > 0
    ]

    if games_with_data:
        weakest_game = min(
            games_with_data,
            key=lambda game: statistics[game]["average"],
        )

        weakest_score = statistics[weakest_game]["average"]

        # If one cognitive area is noticeably weaker,
        # reinforce that area.
        if weakest_score < 60:
            return (
                weakest_game,
                (
                    f"Your recent {weakest_game} performance "
                    f"was {weakest_score:.0f}%, so this area "
                    "is being practiced again."
                ),
            )

    # Avoid repeating the immediately previous game.
    last_game = recent_game_types[-1] if recent_game_types else None

    if average_performance_score < 50:
        candidates = ["memory", "attention", "pattern"]
        selected = next(
            (
                game
                for game in candidates
                if game != last_game
            ),
            "memory",
        )

        return (
            selected,
            "A simpler cognitive exercise is recommended "
            "based on your recent performance.",
        )

    if average_performance_score < 70:
        candidates = ["memory", "attention", "pattern"]
        selected = next(
            (
                game
                for game in candidates
                if game != last_game
            ),
            "memory",
        )

        return (
            selected,
            "A moderate cognitive exercise is recommended "
            "to build consistent performance.",
        )

    if average_performance_score < 85:
        candidates = ["attention", "memory", "pattern"]
        selected = next(
            (
                game
                for game in candidates
                if game != last_game
            ),
            "attention",
        )

        return (
            selected,
            "Your recent performance is good, so "
            "attention and focus training can be introduced.",
        )

    candidates = ["pattern", "attention", "memory"]
    selected = next(
        (
            game
            for game in candidates
            if game != last_game
        ),
        "pattern",
    )

    return (
        selected,
        "Your strong recent performance allows "
        "a more challenging cognitive exercise.",
    )


def recommend_session(
    analytics: dict,
) -> dict:
    """
    Recommend the next cognitive-game session.

    Uses:
        - overall performance
        - recent performance
        - game-specific performance
        - current difficulty
        - performance trend
        - game variety

    This function personalizes engagement and does not
    diagnose or predict a medical condition.
    """
    total_attempts = _safe_int(
        analytics.get("total_attempts"),
        0,
    )

    average_performance_score = _safe_float(
        analytics.get("average_performance_score"),
        0,
    )

    current_difficulty = _safe_int(
        analytics.get("current_difficulty"),
        MIN_DIFFICULTY,
    )

    trend = analytics.get(
        "trend",
        "insufficient_data",
    )

    recent_attempts = get_recent_attempts(
        analytics
    )

    recent_scores = get_recent_scores(
        analytics
    )

    current_difficulty = max(
        MIN_DIFFICULTY,
        min(
            MAX_DIFFICULTY,
            current_difficulty,
        ),
    )

    # First session.
    if total_attempts == 0:
        return {
            "game_type": "memory",
            "difficulty": MIN_DIFFICULTY,
            "reason": (
                "No previous game data is available. "
                "Starting with an easy memory exercise."
            ),
            "trend": "insufficient_data",
            "recent_scores": [],
            "method": "rule_based",
        }

    game_type, reason = select_game_type(
        average_performance_score,
        recent_attempts,
    )

    difficulty = recommend_stable_difficulty(
        current_difficulty=current_difficulty,
        recent_scores=recent_scores,
        minimum_attempts=3,
    )

    # A declining trend should reduce difficulty safely.
    if trend == "declining":
        difficulty = max(
            MIN_DIFFICULTY,
            difficulty - 1,
        )

    # Not enough recent data means don't make a large jump.
    if len(recent_scores) < 3:
        difficulty = current_difficulty

    return {
        "game_type": game_type,
        "difficulty": difficulty,
        "reason": reason,
        "trend": trend,
        "recent_scores": recent_scores[-3:],
        "method": "rule_based",
    }