from statistics import mean


def safe_average(values):

    if not values:
        return 0.0

    return round(
        mean(values),
        2
    )


def build_patient_features(
    attempts
):

    if not attempts:

        return {
            "memory_score": 0.0,
            "attention_score": 0.0,
            "pattern_score": 0.0,
            "average_accuracy": 0.0,
            "average_reaction_time": 0.0,
            "average_hints": 0.0,
            "average_performance": 0.0,
            "current_difficulty": 1
        }

    memory_scores = []
    attention_scores = []
    pattern_scores = []

    accuracies = []
    reaction_times = []
    hints = []
    performance_scores = []

    difficulties = []

    for attempt in attempts:

        game_type = attempt.get(
            "game_type"
        )

        performance = attempt.get(
            "performance_score",
            0
        )

        if game_type == "memory":

            memory_scores.append(
                performance
            )

        elif game_type == "attention":

            attention_scores.append(
                performance
            )

        elif game_type == "pattern":

            pattern_scores.append(
                performance
            )

        accuracies.append(
            attempt.get(
                "accuracy",
                0
            )
        )

        reaction_times.append(
            attempt.get(
                "reaction_time",
                0
            )
        )

        hints.append(
            attempt.get(
                "hints_used",
                0
            )
        )

        performance_scores.append(
            performance
        )

        difficulties.append(
            attempt.get(
                "next_difficulty",
                1
            )
        )

    return {

        "memory_score":
            safe_average(
                memory_scores
            ),

        "attention_score":
            safe_average(
                attention_scores
            ),

        "pattern_score":
            safe_average(
                pattern_scores
            ),

        "average_accuracy":
            safe_average(
                accuracies
            ),

        "average_reaction_time":
            safe_average(
                reaction_times
            ),

        "average_hints":
            safe_average(
                hints
            ),

        "average_performance":
            safe_average(
                performance_scores
            ),

        "current_difficulty":
            difficulties[-1]
    }