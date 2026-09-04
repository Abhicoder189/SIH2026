from statistics import mean, pstdev


GAME_TYPES = (
    "memory",
    "attention",
    "pattern",
)


def calculate_average(values):
    if not values:
        return 0

    return round(mean(values), 2)


def calculate_consistency(performance_scores):
    if len(performance_scores) < 2:
        return "insufficient_data"

    deviation = pstdev(performance_scores)

    if deviation < 10:
        return "consistent"

    return "variable"


def calculate_trend(performance_scores):
    if len(performance_scores) < 3:
        return "insufficient_data"

    midpoint = len(performance_scores) // 2

    older_scores = performance_scores[:midpoint]
    recent_scores = performance_scores[midpoint:]

    older_average = mean(older_scores)
    recent_average = mean(recent_scores)

    difference = recent_average - older_average

    if difference >= 5:
        return "improving"

    if difference <= -5:
        return "declining"

    return "stable"


def calculate_game_analytics(attempts):
    """
    Calculate analytics separately for each game type.
    """

    result = {}

    for game_type in GAME_TYPES:
        game_attempts = [
            attempt
            for attempt in attempts
            if attempt.get("game_type") == game_type
        ]

        if not game_attempts:
            result[game_type] = {
                "total_attempts": 0,
                "average_accuracy": 0,
                "average_reaction_time": 0,
                "average_performance_score": 0,
                "trend": "insufficient_data",
                "consistency": "insufficient_data",
                "current_difficulty": None,
            }
            continue

        accuracy_values = [
            attempt.get("accuracy", 0)
            for attempt in game_attempts
        ]

        reaction_times = [
            attempt.get("reaction_time", 0)
            for attempt in game_attempts
        ]

        performance_scores = [
            attempt.get("performance_score", 0)
            for attempt in game_attempts
        ]

        result[game_type] = {
            "total_attempts": len(game_attempts),

            "average_accuracy": calculate_average(
                accuracy_values
            ),

            "average_reaction_time": calculate_average(
                reaction_times
            ),

            "average_performance_score": calculate_average(
                performance_scores
            ),

            "trend": calculate_trend(
                performance_scores
            ),

            "consistency": calculate_consistency(
                performance_scores
            ),

            "current_difficulty": game_attempts[-1].get(
                "next_difficulty"
            ),
        }

    return result


def analyze_patient_performance(attempts):
    """
    Calculate complete patient-level analytics.
    """

    if not attempts:
        return {
            "total_attempts": 0,
            "average_accuracy": 0,
            "average_reaction_time": 0,
            "average_performance_score": 0,
            "trend": "insufficient_data",
            "consistency": "insufficient_data",
            "current_difficulty": None,
            "games": calculate_game_analytics([]),
        }

    accuracy_values = [
        attempt.get("accuracy", 0)
        for attempt in attempts
    ]

    reaction_times = [
        attempt.get("reaction_time", 0)
        for attempt in attempts
    ]

    performance_scores = [
        attempt.get("performance_score", 0)
        for attempt in attempts
    ]

    current_difficulty = attempts[-1].get(
        "next_difficulty"
    )

    return {
        "total_attempts": len(attempts),

        "average_accuracy": calculate_average(
            accuracy_values
        ),

        "average_reaction_time": calculate_average(
            reaction_times
        ),

        "average_performance_score": calculate_average(
            performance_scores
        ),

        "trend": calculate_trend(
            performance_scores
        ),

        "consistency": calculate_consistency(
            performance_scores
        ),

        "current_difficulty": current_difficulty,

        "games": calculate_game_analytics(
            attempts
        ),
    }