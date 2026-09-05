import os

from dotenv import load_dotenv

from pymongo import MongoClient

from pymongo.server_api import ServerApi


load_dotenv()


MONGODB_URI = os.getenv(
    "MONGODB_URI"
)

DATABASE_NAME = os.getenv(
    "DATABASE_NAME"
)


if not MONGODB_URI:

    raise ValueError(
        "MONGODB_URI is not set in .env"
    )


if not DATABASE_NAME:

    raise ValueError(
        "DATABASE_NAME is not set in .env"
    )


client = MongoClient(
    MONGODB_URI,
    server_api=ServerApi("1"),
    serverSelectionTimeoutMS=5_000,
    connect=False,
)


database = client[
    DATABASE_NAME
]


# ==================================================
# COLLECTIONS
# ==================================================

patients_collection = database[
    "patients"
]

games_collection = database[
    "games"
]

game_attempts_collection = database[
    "game_attempts"
]

game_sessions_collection = database[
    "game_sessions"
]

users_collection = database[
    "users"
]

reminders_collection = database["reminders"]
caregiver_links_collection = database["caregiver_links"]
cognitive_profiles_collection = database["cognitive_profiles"]
daily_activity_collection = database["daily_activity"]
sync_events_collection = database["sync_events"]
revoked_tokens_collection = database["revoked_tokens"]
memories_collection = database["memories"]
memory_interactions_collection = database["memory_interactions"]
journeys_collection = database["journeys"]
family_members_collection = database["family_members"]


# ==================================================
# DATABASE CONNECTION TEST
# ==================================================

def test_database_connection():

    try:

        client.admin.command(
            "ping"
        )

        print(
            "MongoDB connection successful!"
        )

    except Exception as error:

        print(
            "MongoDB connection failed!"
        )

        print(error)
