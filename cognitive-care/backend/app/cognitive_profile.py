from statistics import mean


COGNITIVE_AREAS = {
    "memory": "memory",
    "attention": "attention",
    "pattern": "pattern"
}


def calculate_area_average(
    attempts
):

    if not attempts:
        return None

    scores = [
        attempt.get(
            "performance_score",
            0
        )
        for attempt in attempts
    ]

    return round(
        mean(scores),
        2
    )


def build_cognitive_profile(
    attempts
):

    areas = {}

    for area in COGNITIVE_AREAS:

        area_attempts = [
            attempt
            for attempt in attempts
            if attempt.get(
                "game_type"
            ) == area
        ]

        average_score = (
            calculate_area_average(
                area_attempts
            )
        )

        areas[area] = {

            "attempts":
                len(area_attempts),

            "average_score":
                average_score
        }

    available_scores = {
        area: data["average_score"]
        for area, data in areas.items()
        if data["average_score"] is not None
    }

    strongest_area = None
    weakest_area = None

    if available_scores:

        strongest_area = max(
            available_scores,
            key=available_scores.get
        )

        weakest_area = min(
            available_scores,
            key=available_scores.get
        )

    return {

        "areas":
            areas,

        "strongest_area":
            strongest_area,

        "weakest_area":
            weakest_area
    }