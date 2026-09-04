import random


PATTERNS = {

    1: [
        ["A", "B", "A", "B"],
        ["1", "2", "1", "2"],
        ["X", "Y", "X", "Y"]
    ],

    2: [
        ["A", "B", "C", "A", "B"],
        ["1", "2", "3", "1", "2"],
        ["X", "Y", "Z", "X", "Y"]
    ],

    3: [
        ["A", "B", "C", "B", "A", "B"],
        ["1", "2", "3", "2", "1", "2"],
        ["X", "Y", "Z", "Y", "X", "Y"]
    ],

    4: [
        ["A", "B", "C", "D", "A", "B", "C"],
        ["1", "2", "3", "4", "1", "2", "3"],
        ["W", "X", "Y", "Z", "W", "X", "Y"]
    ],

    5: [
        ["A", "B", "C", "D", "C", "B", "A"],
        ["1", "2", "3", "4", "3", "2", "1"],
        ["W", "X", "Y", "Z", "Y", "X", "W"]
    ]
}


def generate_pattern_challenge(
    difficulty: int
):

    pattern = random.choice(
        PATTERNS[difficulty]
    )

    # The pattern is shown without
    # the final answer.

    visible_pattern = pattern[:-1]

    correct_answer = pattern[-1]

    return {
        "pattern": visible_pattern,
        "correct_answer": correct_answer
    }