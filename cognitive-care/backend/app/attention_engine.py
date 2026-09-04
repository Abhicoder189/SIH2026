import random


SYMBOLS = [
    "circle",
    "square",
    "triangle",
    "star"
]


GRID_SIZE = {
    1: 6,
    2: 9,
    3: 12,
    4: 16,
    5: 20
}


def generate_attention_challenge(
    difficulty: int
):

    total_items = GRID_SIZE[difficulty]

    target = random.choice(
        SYMBOLS
    )

    grid = []

    for _ in range(total_items):

        symbol = random.choice(
            SYMBOLS
        )

        grid.append(
            symbol
        )

    # Make sure the target appears
    # at least once.

    target_position = random.randrange(
        total_items
    )

    grid[target_position] = target

    correct_count = grid.count(
        target
    )

    return {
        "grid": grid,
        "target": target,
        "correct_count": correct_count
    }