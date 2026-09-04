from statistics import mean


def average(values):

    if not values:
        return 0.0

    return mean(values)


def calculate_trend(
    scores
):

    if len(scores) < 3:
        return 0.0

    midpoint = len(scores) // 2

    older = scores[:midpoint]
    recent = scores[midpoint:]

    return (
        average(recent)
        -
        average(older)
    )


def build_training_examples(
    attempts
):

    examples = []

    if len(attempts) < 2:
        return examples

    for index in range(
        1,
        len(attempts)
    ):

        history = attempts[:index]

        current_attempt = attempts[index]

        memory_scores = [
            attempt["performance_score"]
            for attempt in history
            if attempt.get("game_type") == "memory"
        ]

        attention_scores = [
            attempt["performance_score"]
            for attempt in history
            if attempt.get("game_type") == "attention"
        ]

        pattern_scores = [
            attempt["performance_score"]
            for attempt in history
            if attempt.get("game_type") == "pattern"
        ]

        accuracies = [
            attempt.get(
                "accuracy",
                0
            )
            for attempt in history
        ]

        reaction_times = [
            attempt.get(
                "reaction_time",
                0
            )
            for attempt in history
        ]

        hints = [
            attempt.get(
                "hints_used",
                0
            )
            for attempt in history
        ]

        performance_scores = [
            attempt.get(
                "performance_score",
                0
            )
            for attempt in history
        ]

        current_difficulty = history[-1].get(
            "next_difficulty",
            1
        )

        trend = calculate_trend(
            performance_scores
        )

        example = {

            "memory_score":
                average(memory_scores),

            "attention_score":
                average(attention_scores),

            "pattern_score":
                average(pattern_scores),

            "average_accuracy":
                average(accuracies),

            "average_reaction_time":
                average(reaction_times),

            "average_hints":
                average(hints),

            "average_performance":
                average(performance_scores),

            "current_difficulty":
                current_difficulty,

            "trend":
                trend,

            "target_difficulty":
                current_attempt.get(
                    "difficulty",
                    1
                )
        }

        examples.append(
            example
        )

    return examples