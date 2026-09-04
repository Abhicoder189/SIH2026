import os

import pandas as pd

from dotenv import load_dotenv

from pymongo import MongoClient

from pymongo.server_api import ServerApi

from app.training_data import (
    build_training_examples
)


load_dotenv()


MONGODB_URI = os.getenv(
    "MONGODB_URI"
)

DATABASE_NAME = os.getenv(
    "DATABASE_NAME"
)


client = MongoClient(
    MONGODB_URI,
    server_api=ServerApi("1")
)

database = client[
    DATABASE_NAME
]


game_attempts_collection = database[
    "game_attempts"
]


attempts = list(
    game_attempts_collection
    .find()
    .sort(
        "created_at",
        1
    )
)


examples = build_training_examples(
    attempts
)


if not examples:

    print(
        "Not enough game attempts "
        "to build a training dataset."
    )

    print(
        "Play more games first."
    )

    exit()


df = pd.DataFrame(
    examples
)


os.makedirs(
    "../ml/data",
    exist_ok=True
)


output_path = (
    "../ml/data/cognitive_training_data.csv"
)


df.to_csv(
    output_path,
    index=False
)


print(
    "Training dataset created successfully."
)

print(
    f"Rows: {len(df)}"
)

print(
    f"Columns: {list(df.columns)}"
)

print(
    f"Saved to: {output_path}"
)
