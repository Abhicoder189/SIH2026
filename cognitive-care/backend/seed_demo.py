"""Create small, clearly labelled demo accounts and representative activity."""
import os
from datetime import datetime, timedelta, timezone

from pymongo import ReturnDocument

from app.auth import hash_password
from app.database import patients_collection, users_collection
from app.main import record_attempt


def main() -> None:
    password = os.getenv("DEMO_PASSWORD")
    if not password or len(password) < 8:
        raise SystemExit("Set DEMO_PASSWORD to a password of at least eight characters before seeding.")
    email = "demo.elderly@example.invalid"
    user = users_collection.find_one_and_update(
        {"email": email},
        {"$setOnInsert": {"name": "Raj Kumar", "email": email, "password_hash": hash_password(password), "role": "elderly", "created_at": datetime.now(timezone.utc)}},
        upsert=True,
        return_document=ReturnDocument.AFTER,
    )
    patient = patients_collection.find_one_and_update(
        {"user_id": str(user["_id"])},
        {"$setOnInsert": {"user_id": str(user["_id"]), "name": "Raj Kumar", "age": 68, "language": "English", "region": "Assam", "preferences": {}, "created_at": datetime.now(timezone.utc)}},
        upsert=True,
        return_document=ReturnDocument.AFTER,
    )
    patient_id = str(patient["_id"])
    if not list(__import__("app.database", fromlist=["game_attempts_collection"]).game_attempts_collection.find({"patient_id": patient_id}).limit(1)):
        for index, score in enumerate((2, 3, 3)):
            record_attempt(patient_id=patient_id, game_type="memory", difficulty=1, score=score, max_score=3, reaction_time=12-index, hints_used=0, created_at=datetime.now(timezone.utc) - timedelta(days=2-index))
    print(f"Demo elderly account created: {email}")


if __name__ == "__main__":
    main()
