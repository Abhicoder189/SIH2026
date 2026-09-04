from datetime import datetime, timezone


def create_game_session(
    patient_id: str,
    game_type: str,
    difficulty: int,
    challenge_data: dict
):

    session = {

        "patient_id":
            patient_id,

        "game_type":
            game_type,

        "difficulty":
            difficulty,

        "challenge":
            challenge_data,

        "completed":
            False,

        "created_at":
            datetime.now(
                timezone.utc
            )
    }

    return session