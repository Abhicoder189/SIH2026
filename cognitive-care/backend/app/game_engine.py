import random


# ==========================================
# OBJECT DATABASE
# ==========================================

MEMORY_OBJECTS = [
    "apple",
    "milk",
    "lamp",
    "flower",
    "book",
    "cup",
    "rice",
    "umbrella",
    "clock",
    "ball",
    "tree",
    "house",
    "spoon",
    "plate",
    "bottle"
]


# ==========================================
# OBJECT COUNT BY DIFFICULTY
# ==========================================

DIFFICULTY_OBJECT_COUNT = {
    1: 3,
    2: 4,
    3: 5,
    4: 6,
    5: 7
}


# ==========================================
# GENERATE MEMORY CHALLENGE
# ==========================================

def generate_memory_challenge(difficulty: int):

    object_count = DIFFICULTY_OBJECT_COUNT[
        difficulty
    ]

    selected_objects = random.sample(
        MEMORY_OBJECTS,
        object_count
    )

    return selected_objects