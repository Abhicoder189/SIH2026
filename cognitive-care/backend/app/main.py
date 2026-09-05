"""HTTP API for the Cognitive Care prototype.

Scores are engagement metrics for games; this service does not diagnose or
predict dementia or any other medical condition.
"""

from datetime import datetime, timedelta, timezone
import os
import random

from bson import ObjectId
from fastapi import Depends, FastAPI, Header, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware

from .adaptation import calculate_performance_score, recommend_difficulty
from .analytics import analyze_patient_performance
from .attention_engine import generate_attention_challenge
from .auth import (
    create_access_token,
    get_current_user,
    hash_password,
    revoke_token,
    verify_password,
)
from .cognitive_profile import build_cognitive_profile
from .database import (
    caregiver_links_collection,
    cognitive_profiles_collection,
    daily_activity_collection,
    family_members_collection,
    game_attempts_collection,
    game_sessions_collection,
    journeys_collection,
    memories_collection,
    memory_interactions_collection,
    patients_collection,
    reminders_collection,
    sync_events_collection,
    test_database_connection,
    users_collection,
)
from .game_engine import MEMORY_OBJECTS, generate_memory_challenge
from .ml_features import build_patient_features
from .patient_auth import get_my_patient, verify_patient_access
from .pattern_engine import generate_pattern_challenge
from .personalization import recommend_session
from .ml_personalization import ml_recommend_difficulty
from .schemas import (
    AttentionGameSubmit,
    CaregiverLinkCreate,
    FamilyMemberCreate,
    FamilyMemberUpdate,
    GameStart,
    JourneyCreate,
    JourneyLocationUpdate,
    MemoryCreate,
    MemoryGameSubmit,
    MemoryUpdate,
    PatientCreate,
    PatternGameSubmit,
    ReminderCreate,
    ReminderUpdate,
    SyncAttempt,
    SyncReminder,
    TokenResponse,
    UserLogin,
    UserRegister,
)
from .session_manager import create_game_session

from .gemini_voice import interpret_voice_command
# ============================================================
# APP CONFIGURATION
# ============================================================

app = FastAPI(
    title="Cognitive Care API",
    description=(
        "Cognitive-game engagement and memory-assistance platform. "
        "Not a diagnostic tool."
    ),
    version="1.3.0",
)


cors_origins = [
    origin.strip()
    for origin in os.getenv("CORS_ORIGINS", "*").split(",")
    if origin.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================
# COMMON HELPERS
# ============================================================

def now() -> datetime:
    """Return the current UTC time."""
    return datetime.now(timezone.utc)


def object_id(value: str, label: str = "ID") -> ObjectId:
    """Convert a string to MongoDB ObjectId."""
    if not ObjectId.is_valid(value):
        raise HTTPException(
            status_code=400,
            detail=f"Invalid {label}",
        )

    return ObjectId(value)


def serialise(document: dict | None) -> dict | None:
    """Convert MongoDB _id into a JSON-friendly id."""
    if document is None:
        return None

    result = dict(document)

    if "_id" in result:
        result["id"] = str(result.pop("_id"))

    return result


def owned_patient(patient_id: str, current_user: dict) -> dict:
    """Verify that the current user can access the patient."""
    return verify_patient_access(
        patient_id,
        current_user,
    )


# ============================================================
# PATIENT PROFILE / COGNITIVE PROFILE
# ============================================================

def save_profile(patient_id: str) -> dict:
    """Recalculate and save the patient's game-performance profile."""

    attempts = list(
        game_attempts_collection
        .find({"patient_id": patient_id})
        .sort("created_at", 1)
    )

    features = build_patient_features(attempts)

    engagement_score = min(
        100,
        round(
            len(attempts) * 10
            + (features["average_performance"] * 0.5),
            2,
        ),
    )

    profile = {
        "patient_id": patient_id,
        **features,
        "engagement_score": engagement_score,
        "updated_at": now(),
    }

    cognitive_profiles_collection.update_one(
        {"patient_id": patient_id},
        {"$set": profile},
        upsert=True,
    )

    return profile


# ============================================================
# GAME ATTEMPT RECORDING
# ============================================================

def record_attempt(
    *,
    patient_id: str,
    game_type: str,
    difficulty: int,
    score: float,
    max_score: float,
    reaction_time: float,
    hints_used: int,
    session_id: str | None = None,
    created_at: datetime | None = None,
) -> dict:
    """Record one completed game attempt."""

    if max_score <= 0:
        raise HTTPException(
            status_code=400,
            detail="max_score must be greater than zero",
        )

    accuracy = round(
        (score / max_score) * 100,
        2,
    )

    performance_score = calculate_performance_score(
        accuracy,
        reaction_time,
        hints_used,
    )

    attempt = {
        "patient_id": patient_id,
        "game_session_id": session_id,
        "game_type": game_type,
        "difficulty": difficulty,
        "score": score,
        "max_score": max_score,
        "accuracy": accuracy,
        "reaction_time": reaction_time,
        "hints_used": hints_used,
        "performance_score": performance_score,
        "next_difficulty": recommend_difficulty(
            difficulty,
            performance_score,
        ),
        "created_at": created_at or now(),
    }

    # Save attempt to MongoDB.
    result = game_attempts_collection.insert_one(
        attempt
    )

    # IMPORTANT:
    # MongoDB automatically adds an ObjectId as "_id".
    # Do not return that ObjectId directly to FastAPI.
    attempt.pop("_id", None)

    attempt["attempt_id"] = str(
        result.inserted_id
    )

    # Update the patient's calculated profile.
    save_profile(patient_id)

    # Update daily activity.
    activity_date = attempt["created_at"]

    if isinstance(activity_date, datetime):
        activity_date = activity_date.date().isoformat()
    else:
        activity_date = now().date().isoformat()

    daily_activity_collection.update_one(
        {
            "patient_id": patient_id,
            "date": activity_date,
        },
        {
            "$inc": {
                "games_completed": 1,
            },
            "$set": {
                "last_activity_at": attempt[
                    "created_at"
                ],
            },
        },
        upsert=True,
    )

    return attempt

# ============================================================
# GAME SESSION CREATION
# ============================================================

def start_game(
    game: GameStart,
    current_user: dict,
    game_type: str,
) -> dict:
    """Create a game session and return the public challenge."""

    owned_patient(
        game.patient_id,
        current_user,
    )

    # The server is the source of truth for adaptive difficulty.
    # The Flutter client may send a default difficulty, but an existing
    # personalized difficulty must not be accidentally overwritten by it.
    requested_difficulty = int(game.difficulty)
    analytics = patient_analytics(game.patient_id)
    adaptive_difficulty = analytics.get("current_difficulty")
    if isinstance(adaptive_difficulty, int) and 1 <= adaptive_difficulty <= 5:
        effective_difficulty = adaptive_difficulty
    else:
        effective_difficulty = max(1, min(5, requested_difficulty))

    # ---------------- MEMORY ----------------

    if game_type == "memory":
        objects = generate_memory_challenge(
            effective_difficulty
        )

        available_distractors = [
            item
            for item in MEMORY_OBJECTS
            if item not in objects
        ]

        distractor_count = min(
            3,
            len(available_distractors),
        )

        distractors = random.sample(
            available_distractors,
            distractor_count,
        )

        options = random.sample(
            objects + distractors,
            len(objects) + len(distractors),
        )

        challenge = {
            "objects": objects,
            "options": options,
        }

        public_challenge = {
            "objects": objects,
            "options": options,
        }

    # ---------------- PATTERN ----------------

    elif game_type == "pattern":
        challenge = generate_pattern_challenge(
            effective_difficulty
        )

        public_challenge = {
            "pattern": challenge["pattern"],
        }

    # ---------------- ATTENTION ----------------

    elif game_type == "attention":
        challenge = generate_attention_challenge(
            effective_difficulty
        )

        public_challenge = {
            "grid": challenge["grid"],
            "target": challenge["target"],
        }

    else:
        raise HTTPException(
            status_code=400,
            detail="Unsupported game type",
        )

    # Create database session.
    session = create_game_session(
        game.patient_id,
        game_type,
        effective_difficulty,
        challenge,
    )

    session["started_by"] = current_user["user_id"]

    result = game_sessions_collection.insert_one(
        session
    )

    session_id = str(result.inserted_id)

    return {
        "game_session_id": session_id,
        "difficulty": effective_difficulty,
        "requested_difficulty": requested_difficulty,
        "game_type": game_type,
        "challenge": public_challenge,
        **public_challenge,
    }


# ============================================================
# GAME SESSION VALIDATION
# ============================================================

def session_for_submission(
    session_id: str,
    patient_id: str,
    game_type: str,
    current_user: dict,
) -> dict:
    """Validate a game session before accepting an answer."""

    owned_patient(
        patient_id,
        current_user,
    )

    session = game_sessions_collection.find_one(
        {
            "_id": object_id(
                session_id,
                "game session ID",
            )
        }
    )

    if not session:
        raise HTTPException(
            status_code=404,
            detail="Game session not found",
        )

    if session.get("patient_id") != patient_id:
        raise HTTPException(
            status_code=403,
            detail="Game session does not belong to this patient",
        )

    if session.get("game_type") != game_type:
        raise HTTPException(
            status_code=403,
            detail="Game session does not belong to this activity",
        )

    if session.get("completed"):
        raise HTTPException(
            status_code=409,
            detail="This game session was already submitted",
        )

    return session


# ============================================================
# STARTUP
# ============================================================

@app.on_event("startup")
def startup_event() -> None:
    test_database_connection()


# ============================================================
# HEALTH CHECK
# ============================================================

@app.get("/")
def home() -> dict:
    return {
        "message": "Cognitive Care API is running",
        "version": "1.2.0",
        "medical_notice": (
            "Game performance is not a diagnosis."
        ),
    }


@app.get("/health")
def health() -> dict:
    """Simple health endpoint for frontend/deployment checks."""
    return {
        "status": "ok",
        "service": "cognitive-care-api",
        "timestamp": now(),
    }


# ============================================================
# AUTHENTICATION
# ============================================================

@app.post(
    "/auth/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
)
def register_user(user: UserRegister) -> dict:
    """Register a new user."""

    email = user.email.strip().lower()

    existing_user = users_collection.find_one(
        {"email": email}
    )

    if existing_user:
        raise HTTPException(
            status_code=409,
            detail="Email already registered",
        )

    user_document = {
        "name": user.name.strip(),
        "email": email,
        "password_hash": hash_password(
            user.password
        ),
        "role": user.role,
        "created_at": now(),
    }

    user_result = users_collection.insert_one(
        user_document
    )

    user_id = str(user_result.inserted_id)

    # Automatically create the patient profile
    # for elderly accounts.
    if user.role == "elderly":
        patients_collection.insert_one(
            {
                "user_id": user_id,
                "name": user.name.strip(),
                "age": user.age,
                "language": user.language,
                "preferences": {},
                "created_at": now(),
            }
        )

    access_token = create_access_token(
        user_id,
        user.role,
    )

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": user_id,
        "role": user.role,
    }


@app.post(
    "/auth/login",
    response_model=TokenResponse,
)
def login_user(user: UserLogin) -> dict:
    """Authenticate an existing user."""

    email = user.email.strip().lower()

    existing = users_collection.find_one(
        {"email": email}
    )

    if not existing:
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password",
        )

    if not verify_password(
        user.password,
        existing["password_hash"],
    ):
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password",
        )

    user_id = str(existing["_id"])
    role = existing["role"]

    access_token = create_access_token(
        user_id,
        role,
    )

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": user_id,
        "role": role,
    }


@app.post(
    "/auth/logout",
    status_code=status.HTTP_204_NO_CONTENT,
)
def logout(
    authorization: str | None = Header(default=None),
) -> None:
    """Revoke the current token."""

    if (
        authorization
        and authorization.lower().startswith("bearer ")
    ):
        revoke_token(
            authorization[7:]
        )


@app.get("/auth/me")
def get_my_profile(
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Return authenticated user information."""

    user = users_collection.find_one(
        {
            "_id": object_id(
                current_user["user_id"],
                "user ID",
            )
        }
    )

    if not user:
        raise HTTPException(
            status_code=404,
            detail="User not found",
        )

    return {
        "user_id": str(user["_id"]),
        "name": user["name"],
        "email": user["email"],
        "role": user["role"],
    }


# ============================================================
# PATIENT
# ============================================================

@app.get("/patients/me")
def get_my_patient_profile(
    patient: dict = Depends(get_my_patient),
) -> dict:
    return {
        "patient_id": str(patient["_id"]),
        "user_id": patient["user_id"],
        "name": patient["name"],
        "age": patient["age"],
        "language": patient["language"],
        "region": patient.get("region"),
    }


@app.post(
    "/patients",
    status_code=status.HTTP_201_CREATED,
)
def create_patient(
    patient: PatientCreate,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Create a patient profile for an elderly account."""

    if current_user["role"] != "elderly":
        raise HTTPException(
            status_code=403,
            detail="Only elderly accounts can create their profile",
        )

    existing = patients_collection.find_one(
        {
            "user_id": current_user["user_id"]
        }
    )

    if existing:
        raise HTTPException(
            status_code=409,
            detail="Patient profile already exists",
        )

    result = patients_collection.insert_one(
        {
            "user_id": current_user["user_id"],
            **patient.model_dump(),
            "preferences": {},
            "created_at": now(),
        }
    )

    return {
        "patient_id": str(result.inserted_id)
    }


@app.get("/patients/{patient_id}")
def get_patient(
    patient_id: str,
    current_user: dict = Depends(get_current_user),
) -> dict:
    patient = owned_patient(
        patient_id,
        current_user,
    )

    return serialise(patient)


# ============================================================
# GAMES
# ============================================================

@app.get("/games")
def get_games() -> list[dict]:
    return [
        {
            "id": "memory",
            "name": "Memory Game",
            "category": "memory",
            "active": True,
        },
        {
            "id": "pattern",
            "name": "Pattern Game",
            "category": "pattern",
            "active": True,
        },
        {
            "id": "attention",
            "name": "Attention Game",
            "category": "attention",
            "active": True,
        },
    ]


@app.post("/memory-game/start")
def start_memory_game(
    game: GameStart,
    current_user: dict = Depends(get_current_user),
) -> dict:
    return start_game(
        game,
        current_user,
        "memory",
    )


@app.post("/pattern-game/start")
def start_pattern_game(
    game: GameStart,
    current_user: dict = Depends(get_current_user),
) -> dict:
    return start_game(
        game,
        current_user,
        "pattern",
    )


@app.post("/attention-game/start")
def start_attention_game(
    game: GameStart,
    current_user: dict = Depends(get_current_user),
) -> dict:
    return start_game(
        game,
        current_user,
        "attention",
    )


# ============================================================
# MEMORY GAME SUBMISSION
# ============================================================

@app.post("/memory-game/submit")
def submit_memory_game(
    submission: MemoryGameSubmit,
    current_user: dict = Depends(get_current_user),
) -> dict:
    session = session_for_submission(
        submission.game_session_id,
        submission.patient_id,
        "memory",
        current_user,
    )

    correct_objects = set(
        session["challenge"]["objects"]
    )

    selected_objects = set(
        submission.selected_objects
    )

    correct_count = len(
        correct_objects & selected_objects
    )

    attempt = record_attempt(
        patient_id=submission.patient_id,
        game_type="memory",
        difficulty=session["difficulty"],
        score=correct_count,
        max_score=len(correct_objects),
        reaction_time=submission.reaction_time,
        hints_used=submission.hints_used,
        session_id=submission.game_session_id,
    )

    game_sessions_collection.update_one(
        {"_id": session["_id"]},
        {
            "$set": {
                "completed": True,
                "completed_at": now(),
            }
        },
    )

    return {
        "message": "Memory game completed",
        "correct_count": correct_count,
        "total_objects": len(correct_objects),
        **attempt,
    }


# ============================================================
# PATTERN GAME SUBMISSION
# ============================================================

@app.post("/pattern-game/submit")
def submit_pattern_game(
    submission: PatternGameSubmit,
    current_user: dict = Depends(get_current_user),
) -> dict:
    session = session_for_submission(
        submission.game_session_id,
        submission.patient_id,
        "pattern",
        current_user,
    )

    correct_answer = session["challenge"][
        "correct_answer"
    ]

    correct = (
        submission.answer.strip().upper()
        == correct_answer.strip().upper()
    )

    attempt = record_attempt(
        patient_id=submission.patient_id,
        game_type="pattern",
        difficulty=session["difficulty"],
        score=int(correct),
        max_score=1,
        reaction_time=submission.reaction_time,
        hints_used=submission.hints_used,
        session_id=submission.game_session_id,
    )

    game_sessions_collection.update_one(
        {"_id": session["_id"]},
        {
            "$set": {
                "completed": True,
                "completed_at": now(),
            }
        },
    )

    return {
        "message": "Pattern game completed",
        "correct": correct,
        "correct_answer": correct_answer,
        **attempt,
    }


# ============================================================
# ATTENTION GAME SUBMISSION
# ============================================================

@app.post("/attention-game/submit")
def submit_attention_game(
    submission: AttentionGameSubmit,
    current_user: dict = Depends(get_current_user),
) -> dict:
    session = session_for_submission(
        submission.game_session_id,
        submission.patient_id,
        "attention",
        current_user,
    )

    correct_count = session["challenge"][
        "correct_count"
    ]

    is_correct = (
        submission.answer == correct_count
    )

    attempt = record_attempt(
        patient_id=submission.patient_id,
        game_type="attention",
        difficulty=session["difficulty"],
        score=int(is_correct),
        max_score=1,
        reaction_time=submission.reaction_time,
        hints_used=submission.hints_used,
        session_id=submission.game_session_id,
    )

    game_sessions_collection.update_one(
        {"_id": session["_id"]},
        {
            "$set": {
                "completed": True,
                "completed_at": now(),
            }
        },
    )

    return {
        "message": "Attention game completed",
        "correct": is_correct,
        "correct_count": correct_count,
        **attempt,
    }


# ============================================================
# ANALYTICS
# ============================================================

def patient_analytics(patient_id: str) -> dict:
    """Calculate complete analytics for one patient."""

    attempts = list(
        game_attempts_collection
        .find({"patient_id": patient_id})
        .sort("created_at", 1)
    )

    base = analyze_patient_performance(
        attempts
    )

    total_sessions = (
        game_sessions_collection.count_documents(
            {"patient_id": patient_id}
        )
    )

    completed_sessions = (
        game_sessions_collection.count_documents(
            {
                "patient_id": patient_id,
                "completed": True,
            }
        )
    )

    games_by_type = {
        game_type: sum(
            attempt.get("game_type") == game_type
            for attempt in attempts
        )
        for game_type in (
            "memory",
            "pattern",
            "attention",
        )
    }

    return {
        **base,
        "total_sessions": total_sessions,
        "completed_sessions": completed_sessions,
        "games_by_type": games_by_type,
    }


@app.get(
    "/analytics/patient/{patient_id}"
)
@app.get(
    "/patients/{patient_id}/performance"
)
def get_patient_performance(
    patient_id: str,
    current_user: dict = Depends(get_current_user),
) -> dict:
    patient = owned_patient(
        patient_id,
        current_user,
    )

    return {
        "patient_id": patient_id,
        "patient_name": patient["name"],
        "analytics": patient_analytics(
            patient_id
        ),
    }


@app.get(
    "/analytics/patient/{patient_id}/summary"
)
def get_analytics_summary(
    patient_id: str,
    current_user: dict = Depends(get_current_user),
) -> dict:
    owned_patient(
        patient_id,
        current_user,
    )

    analytics = patient_analytics(
        patient_id
    )

    return {
        key: analytics.get(key)
        for key in (
            "total_sessions",
            "completed_sessions",
            "average_accuracy",
            "average_reaction_time",
            "average_performance_score",
            "trend",
            "current_difficulty",
        )
    }


@app.get(
    "/analytics/patient/{patient_id}/trends"
)
def get_analytics_trends(
    patient_id: str,
    current_user: dict = Depends(get_current_user),
) -> dict:
    owned_patient(
        patient_id,
        current_user,
    )

    attempts = list(
        game_attempts_collection
        .find({"patient_id": patient_id})
        .sort("created_at", 1)
    )

    analytics = analyze_patient_performance(
        attempts
    )

    return {
        "trend": analytics["trend"],
        "points": [
            {
                "date": attempt["created_at"],
                "score": attempt["performance_score"],
                "difficulty": attempt["difficulty"],
                "game_type": attempt["game_type"],
            }
            for attempt in attempts
        ],
    }


@app.get(
    "/analytics/patient/{patient_id}/games"
)
def get_game_attempts(
    patient_id: str,
    current_user: dict = Depends(get_current_user),
) -> list[dict]:
    owned_patient(
        patient_id,
        current_user,
    )

    attempts = (
        game_attempts_collection
        .find({"patient_id": patient_id})
        .sort("created_at", -1)
        .limit(50)
    )

    return [
        serialise(attempt)
        for attempt in attempts
    ]

@app.get("/patients/{patient_id}/difficulty-recommendation")
def get_difficulty_recommendation(
    patient_id: str,
    current_user: dict = Depends(get_current_user),
) -> dict:

    analytics = patient_analytics(patient_id)

    attempts = list(
        db.game_attempts.find(
            {"patient_id": patient_id}
        ).sort("created_at", 1)
    )

    fallback = analytics.get(
        "current_difficulty",
        1,
    )

    try:
        fallback = int(fallback)
    except (TypeError, ValueError):
        fallback = 1

    recommendation = ml_recommend_difficulty(
        attempts=attempts,
        fallback=fallback,
    )

    return {
        "patient_id": patient_id,
        "difficulty": recommendation["difficulty"],
        "method": recommendation["method"],
        "confidence": recommendation.get("confidence"),
        "training_samples": recommendation.get(
            "training_samples",
            0,
        ),
        "classes": recommendation.get(
            "classes",
            [],
        ),
    }

# ============================================================
# AI / PERSONALIZATION
# ============================================================

@app.get(
    "/ai/profile/{patient_id}"
)
@app.get(
    "/patients/{patient_id}/cognitive-profile"
)
def get_cognitive_profile(
    patient_id: str,
    current_user: dict = Depends(get_current_user),
) -> dict:
    owned_patient(
        patient_id,
        current_user,
    )

    attempts = list(
        game_attempts_collection
        .find({"patient_id": patient_id})
        .sort("created_at", 1)
    )

    return {
        "patient_id": patient_id,
        "activity_performance": build_cognitive_profile(
            attempts
        ),
        "profile": save_profile(
            patient_id
        ),
        "notice": (
            "This is game-performance data, "
            "not a diagnosis."
        ),
    }


@app.post(
    "/ai/recommendation/{patient_id}"
)
@app.get(
    "/patients/{patient_id}/next-session"
)
def get_next_session(
    patient_id: str,
    current_user: dict = Depends(get_current_user),
) -> dict:
    owned_patient(
        patient_id,
        current_user,
    )

    analytics = patient_analytics(
        patient_id
    )

    recommendation = recommend_session(analytics)
    attempts = list(
        game_attempts_collection
        .find({"patient_id": patient_id})
        .sort("created_at", 1)
    )
    ml_result = ml_recommend_difficulty(
        attempts,
        recommendation["difficulty"],
    )
    recommendation["difficulty"] = ml_result["difficulty"]
    recommendation["method"] = ml_result["method"]
    recommendation["ml_confidence"] = ml_result["confidence"]
    if "training_samples" in ml_result:
        recommendation["training_samples"] = ml_result["training_samples"]

    return {
        "patient_id": patient_id,
        "method": recommendation["method"],
        "recommendation": recommendation,
        "notice": (
            "Personalization recommends game difficulty from activity data; "
            "it is not a medical diagnosis."
        ),
    }


# ============================================================
# REMINDERS
# ============================================================

@app.get("/reminders")
def get_reminders(
    patient_id: str | None = Query(default=None),
    current_user: dict = Depends(get_current_user),
) -> list[dict]:
    """Get reminders for the current user/patient."""

    if patient_id is None:
        if current_user["role"] != "elderly":
            raise HTTPException(
                status_code=400,
                detail=(
                    "patient_id is required "
                    "for caregiver accounts"
                ),
            )

        patient_id = str(
            get_my_patient(
                current_user
            )["_id"]
        )

    # Elderly users can access their own profile.
    if current_user["role"] == "elderly":
        owned_patient(
            patient_id,
            current_user,
        )

    # Caregivers need an active link.
    elif current_user["role"] == "caregiver":
        link = caregiver_links_collection.find_one(
            {
                "caregiver_id": current_user["user_id"],
                "patient_id": patient_id,
                "status": "active",
            }
        )

        if not link:
            raise HTTPException(
                status_code=403,
                detail="Patient is not linked to this caregiver",
            )

    else:
        raise HTTPException(
            status_code=403,
            detail="Insufficient permissions",
        )

    reminders = (
        reminders_collection
        .find({"patient_id": patient_id})
        .sort("scheduled_time", 1)
    )

    return [
        serialise(item)
        for item in reminders
    ]


@app.post(
    "/reminders",
    status_code=status.HTTP_201_CREATED,
)
def create_reminder(
    reminder: ReminderCreate,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Create a reminder."""

    patient_id = reminder.patient_id

    if current_user["role"] == "elderly":
        owned_patient(
            patient_id,
            current_user,
        )

    elif current_user["role"] == "caregiver":
        link = caregiver_links_collection.find_one(
            {
                "caregiver_id": current_user["user_id"],
                "patient_id": patient_id,
                "status": "active",
            }
        )

        if not link:
            raise HTTPException(
                status_code=403,
                detail="Patient is not linked to this caregiver",
            )

    else:
        raise HTTPException(
            status_code=403,
            detail="Insufficient permissions",
        )

    result = reminders_collection.insert_one(
        {
            **reminder.model_dump(),
            "completed": False,
            "created_at": now(),
        }
    )

    return {
        "reminder_id": str(result.inserted_id)
    }


@app.put(
    "/reminders/{reminder_id}"
)
def update_reminder(
    reminder_id: str,
    update: ReminderUpdate,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Update or snooze a reminder."""

    reminder = reminders_collection.find_one(
        {
            "_id": object_id(
                reminder_id,
                "reminder ID",
            )
        }
    )

    if not reminder:
        raise HTTPException(
            status_code=404,
            detail="Reminder not found",
        )

    patient_id = reminder["patient_id"]

    if current_user["role"] == "elderly":
        owned_patient(
            patient_id,
            current_user,
        )

    elif current_user["role"] == "caregiver":
        link = caregiver_links_collection.find_one(
            {
                "caregiver_id": current_user["user_id"],
                "patient_id": patient_id,
                "status": "active",
            }
        )

        if not link:
            raise HTTPException(
                status_code=403,
                detail="Patient is not linked to this caregiver",
            )

    else:
        raise HTTPException(
            status_code=403,
            detail="Insufficient permissions",
        )

    changes = update.model_dump(
        exclude_none=True
    )

    if "snooze_minutes" in changes:
        snooze_minutes = changes.pop(
            "snooze_minutes"
        )

        reminder_time = (
            now()
            + timedelta(
                minutes=snooze_minutes
            )
        )

        changes.update(
            {
                "scheduled_time": reminder_time,
                "completed": False,
            }
        )

    if changes:
        reminders_collection.update_one(
            {"_id": reminder["_id"]},
            {"$set": changes},
        )

    return {
        "reminder_id": reminder_id,
        "updated": True,
    }


@app.delete(
    "/reminders/{reminder_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_reminder(
    reminder_id: str,
    current_user: dict = Depends(get_current_user),
) -> None:
    """Delete a reminder."""

    reminder = reminders_collection.find_one(
        {
            "_id": object_id(
                reminder_id,
                "reminder ID",
            )
        }
    )

    if not reminder:
        raise HTTPException(
            status_code=404,
            detail="Reminder not found",
        )

    patient_id = reminder["patient_id"]

    if current_user["role"] == "elderly":
        owned_patient(
            patient_id,
            current_user,
        )

    elif current_user["role"] == "caregiver":
        link = caregiver_links_collection.find_one(
            {
                "caregiver_id": current_user["user_id"],
                "patient_id": patient_id,
                "status": "active",
            }
        )

        if not link:
            raise HTTPException(
                status_code=403,
                detail="Patient is not linked to this caregiver",
            )

    else:
        raise HTTPException(
            status_code=403,
            detail="Insufficient permissions",
        )

    reminders_collection.delete_one(
        {
            "_id": reminder["_id"]
        }
    )


# ============================================================
# OFFLINE SYNC
# ============================================================

@app.post("/sync/attempts")
def sync_attempt(
    attempt: SyncAttempt,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Synchronise an offline game attempt."""

    owned_patient(
        attempt.patient_id,
        current_user,
    )

    duplicate = sync_events_collection.find_one(
        {
            "patient_id": attempt.patient_id,
            "client_event_id": attempt.client_event_id,
        }
    )

    if duplicate:
        return {
            "status": "already_synced",
            "attempt_id": duplicate.get(
                "attempt_id"
            ),
        }

    saved = record_attempt(
        patient_id=attempt.patient_id,
        game_type=attempt.game_type,
        difficulty=attempt.difficulty,
        score=attempt.score,
        max_score=attempt.max_score,
        reaction_time=attempt.reaction_time,
        hints_used=attempt.hints_used,
        session_id=attempt.game_session_id,
        created_at=attempt.completed_at,
    )

    sync_events_collection.insert_one(
        {
            "patient_id": attempt.patient_id,
            "client_event_id": attempt.client_event_id,
            "attempt_id": saved["attempt_id"],
            "created_at": now(),
        }
    )

    return {
        "status": "synced",
        "attempt_id": saved["attempt_id"],
    }


@app.post("/sync/reminders")
def sync_reminder(
    event: SyncReminder,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Synchronise reminder completion."""

    reminder = reminders_collection.find_one(
        {
            "_id": object_id(
                event.reminder_id,
                "reminder ID",
            )
        }
    )

    if not reminder:
        raise HTTPException(
            status_code=404,
            detail="Reminder not found",
        )

    patient_id = reminder["patient_id"]

    if current_user["role"] == "elderly":
        owned_patient(
            patient_id,
            current_user,
        )

    elif current_user["role"] == "caregiver":
        link = caregiver_links_collection.find_one(
            {
                "caregiver_id": current_user["user_id"],
                "patient_id": patient_id,
                "status": "active",
            }
        )

        if not link:
            raise HTTPException(
                status_code=403,
                detail="Patient is not linked to this caregiver",
            )

    else:
        raise HTTPException(
            status_code=403,
            detail="Insufficient permissions",
        )

    duplicate = sync_events_collection.find_one(
        {
            "patient_id": patient_id,
            "client_event_id": event.client_event_id,
        }
    )

    if duplicate:
        return {
            "status": "already_synced"
        }

    reminders_collection.update_one(
        {
            "_id": reminder["_id"]
        },
        {
            "$set": {
                "completed": event.completed,
                "completed_at": event.occurred_at,
            }
        },
    )

    sync_events_collection.insert_one(
        {
            "patient_id": patient_id,
            "client_event_id": event.client_event_id,
            "created_at": now(),
        }
    )

    return {
        "status": "synced"
    }


# ============================================================
# DAILY ROUTINE / ACTIVITY SUPPORT
# ============================================================

@app.get("/patients/{patient_id}/daily-activity")
def get_daily_activity(
    patient_id: str,
    date: str | None = Query(default=None),
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Return a simple daily support summary for the patient."""
    owned_patient(patient_id, current_user)
    day = date or now().date().isoformat()
    item = daily_activity_collection.find_one(
        {"patient_id": patient_id, "date": day}
    )
    reminders = list(
        reminders_collection.find({"patient_id": patient_id})
        .sort("scheduled_time", 1)
    )
    due = []
    for reminder in reminders:
        if reminder.get("completed"):
            continue
        due.append(serialise(reminder))
    attempts = list(
        game_attempts_collection.find({"patient_id": patient_id})
        .sort("created_at", -1)
        .limit(20)
    )
    return {
        "date": day,
        "games_completed": int((item or {}).get("games_completed", 0) or 0),
        "minutes_active": int((item or {}).get("minutes_active", 0) or 0),
        "reminders_pending": len(due),
        "pending_reminders": due[:10],
        "recent_games": [serialise(a) for a in attempts[:5]],
    }


@app.post("/patients/{patient_id}/daily-activity")
def update_daily_activity(
    patient_id: str,
    payload: dict,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Record non-medical daily engagement metrics."""
    owned_patient(patient_id, current_user)
    day = str(payload.get("date") or now().date().isoformat())
    games = max(0, int(payload.get("games_completed", 0) or 0))
    minutes = max(0, int(payload.get("minutes_active", 0) or 0))
    result = daily_activity_collection.update_one(
        {"patient_id": patient_id, "date": day},
        {
            "$inc": {
                "games_completed": games,
                "minutes_active": minutes,
            },
            "$set": {"updated_at": now()},
            "$setOnInsert": {"patient_id": patient_id, "date": day},
        },
        upsert=True,
    )
    return {"updated": True, "date": day, "matched": result.matched_count}


# ============================================================
# CAREGIVER ALERTS
# ============================================================

def _caregiver_can_access(patient_id: str, current_user: dict) -> bool:
    if current_user.get("role") != "caregiver":
        return False
    return caregiver_links_collection.find_one(
        {
            "caregiver_id": current_user["user_id"],
            "patient_id": patient_id,
            "status": "active",
        }
    ) is not None


def build_patient_alerts(patient_id: str) -> list[dict]:
    """Generate explainable engagement alerts; these are not medical alerts."""
    alerts: list[dict] = []
    analytics = patient_analytics(patient_id)

    if analytics.get("trend") == "declining":
        alerts.append({
            "type": "performance",
            "severity": "medium",
            "title": "Recent performance is declining",
            "message": "Consider offering a gentler activity and checking in with the patient.",
        })

    if int(analytics.get("total_attempts", 0) or 0) == 0:
        alerts.append({
            "type": "engagement",
            "severity": "low",
            "title": "No game activity yet",
            "message": "The patient has no recorded game attempts yet.",
        })

    reminders = list(reminders_collection.find({"patient_id": patient_id}))
    overdue = 0
    current = now()
    for reminder in reminders:
        scheduled = reminder.get("scheduled_time")
        if scheduled and not reminder.get("completed"):
            if scheduled.tzinfo is None:
                scheduled = scheduled.replace(tzinfo=timezone.utc)
            if scheduled < current:
                overdue += 1
    if overdue:
        alerts.append({
            "type": "reminder",
            "severity": "medium",
            "title": "Pending reminders",
            "message": f"{overdue} reminder(s) are still incomplete.",
        })

    return alerts


@app.get("/caregiver/patients/{patient_id}/alerts")
def caregiver_alerts(
    patient_id: str,
    current_user: dict = Depends(get_current_user),
) -> dict:
    if not _caregiver_can_access(patient_id, current_user):
        raise HTTPException(status_code=403, detail="Patient is not linked to this caregiver")
    return {
        "patient_id": patient_id,
        "alerts": build_patient_alerts(patient_id),
        "notice": "Alerts describe engagement and reminder activity only; they are not medical alerts.",
    }


@app.get("/patients/{patient_id}/alerts")
def patient_alerts(
    patient_id: str,
    current_user: dict = Depends(get_current_user),
) -> dict:
    owned_patient(patient_id, current_user)
    return {
        "patient_id": patient_id,
        "alerts": build_patient_alerts(patient_id),
    }


# ============================================================
# PATIENT PREFERENCES / LANGUAGE
# ============================================================

@app.get("/patients/{patient_id}/preferences")
def get_preferences(
    patient_id: str,
    current_user: dict = Depends(get_current_user),
) -> dict:
    patient = owned_patient(patient_id, current_user)
    return {
        "patient_id": patient_id,
        "language": patient.get("language", "English"),
        "region": patient.get("region", "NER"),
        "voice_enabled": patient.get("voice_enabled", True),
        "large_text": patient.get("large_text", True),
    }


@app.put("/patients/{patient_id}/preferences")
def update_preferences(
    patient_id: str,
    payload: dict,
    current_user: dict = Depends(get_current_user),
) -> dict:
    owned_patient(patient_id, current_user)
    allowed_languages = {
        "English", "Hindi", "Assamese", "Bengali", "Manipuri",
        "Mizo", "Khasi", "Garo", "Tripuri", "Nagamese",
    }
    changes: dict = {}
    if "language" in payload:
        language = str(payload["language"])
        if language not in allowed_languages:
            raise HTTPException(status_code=400, detail="Unsupported language")
        changes["language"] = language
    if "region" in payload:
        changes["region"] = str(payload["region"]).strip()[:50]
    for key in ("voice_enabled", "large_text"):
        if key in payload:
            changes[key] = bool(payload[key])
    if changes:
        patients_collection.update_one(
            {"_id": object_id(patient_id, "patient ID")},
            {"$set": changes},
        )
    return get_preferences(patient_id, current_user)


# ============================================================
# REMINDER / NOTIFICATION FEED
# ============================================================

@app.get("/patients/{patient_id}/notification-feed")
def notification_feed(
    patient_id: str,
    current_user: dict = Depends(get_current_user),
) -> dict:
    owned_patient(patient_id, current_user)
    current = now()
    reminders = list(
        reminders_collection.find({"patient_id": patient_id, "completed": False})
        .sort("scheduled_time", 1)
        .limit(20)
    )
    feed = []
    for reminder in reminders:
        scheduled = reminder.get("scheduled_time")
        due = False
        if scheduled:
            if scheduled.tzinfo is None:
                scheduled = scheduled.replace(tzinfo=timezone.utc)
            due = scheduled <= current
        feed.append({
            "id": str(reminder.get("_id")),
            "title": reminder.get("title", "Reminder"),
            "message": reminder.get("message", ""),
            "scheduled_time": scheduled,
            "due": due,
            "type": reminder.get("type", "activity"),
        })
    return {"items": feed, "server_time": current}


# ============================================================
# REGIONAL CONTENT
# ============================================================

@app.get("/content/languages")
def languages() -> dict:
    return {
        "languages": [
            "English",
            "Hindi",
            "Assamese",
            "Bengali",
            "Manipuri",
            "Mizo",
            "Khasi",
            "Garo",
            "Tripuri",
            "Nagamese",
        ],
        "voice_note": (
            "Speech recognition and speech output depend "
            "on the device and selected language."
        ),
    }


@app.get("/content/packs/{region}")
def content_pack(
    region: str,
) -> dict:
    return {
        "region": region.title(),
        "objects": MEMORY_OBJECTS,
        "themes": [
            "home",
            "market",
            "garden",
            "local scenery",
        ],
        "notice": (
            "Content is configurable and avoids "
            "regional stereotypes."
        ),
    }


# ============================================================
# VOICE COMMAND FALLBACK
# ============================================================




@app.post("/voice/command")
def voice_command(
    payload: dict,
    current_user: dict = Depends(get_current_user),
) -> dict:

    text = str(
        payload.get("text", "")
    ).strip()

    language = str(
        payload.get("language", "en")
    ).lower()

    history = payload.get("history", [])

    if not isinstance(history, list):
        history = []

    if not text:
        return {
            "intent": "unknown",
            "response": "Please say something.",
            "language": language,
        }

    try:
        result = interpret_voice_command(
            text=text,
            preferred_language=language,
            history=history,
        )

        allowed_intents = {
            "start_memory",
            "start_attention",
            "start_pattern",
            "read_reminders",
            "help",
            "repeat",
            "unknown",
        }

        intent = result.get("intent", "unknown")

        if intent not in allowed_intents:
            intent = "unknown"

        return {
            "intent": intent,
            "response": str(
                result.get(
                    "response",
                    "Sorry, I could not understand that.",
                )
            ),
            "language": str(
                result.get("language", language)
            ),
        }

    except Exception:
        return {
            "intent": "unknown",
            "response": (
                "Sorry, I could not understand that. "
                "Please try again."
            ),
            "language": language,
        }

# ============================================================
# CAREGIVER LINKING
# ============================================================

@app.post(
    "/caregiver/links",
    status_code=status.HTTP_201_CREATED,
)
def request_caregiver_link(
    link: CaregiverLinkCreate,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Caregiver requests access to a patient."""

    if current_user["role"] != "caregiver":
        raise HTTPException(
            status_code=403,
            detail="Only caregiver accounts can request a link",
        )

    patient_id = link.patient_id.strip()

    object_id(
        patient_id,
        "patient ID",
    )

    patient = patients_collection.find_one(
        {
            "_id": object_id(
                patient_id,
                "patient ID",
            )
        }
    )

    if not patient:
        raise HTTPException(
            status_code=404,
            detail="Patient not found",
        )

    # Prevent duplicate links.
    existing = caregiver_links_collection.find_one(
        {
            "caregiver_id": current_user["user_id"],
            "patient_id": patient_id,
        }
    )

    if existing:
        return {
            "link_id": str(existing["_id"]),
            "patient_id": patient_id,
            "status": existing["status"],
            "relationship": existing.get(
                "relationship",
                "Caregiver",
            ),
        }

    result = caregiver_links_collection.insert_one(
        {
            "caregiver_id": current_user["user_id"],
            "patient_id": patient_id,
            "relationship": link.relationship,
            "status": "pending",
            "created_at": now(),
        }
    )

    return {
        "link_id": str(result.inserted_id),
        "status": "pending",
        "patient_id": patient_id,
    }


@app.get(
    "/caregiver/requests"
)
def caregiver_requests(
    patient: dict = Depends(get_my_patient),
) -> list[dict]:
    """Return pending caregiver requests for the elderly user."""

    links = caregiver_links_collection.find(
        {
            "patient_id": str(patient["_id"]),
            "status": "pending",
        }
    )

    result = []

    for link in links:
        caregiver = users_collection.find_one(
            {
                "_id": object_id(
                    link["caregiver_id"],
                    "caregiver ID",
                )
            }
        )

        result.append(
            {
                "id": str(link["_id"]),
                "caregiver_id": link["caregiver_id"],
                "caregiver_name": (
                    caregiver.get("name")
                    if caregiver
                    else "Caregiver"
                ),
                "patient_id": link["patient_id"],
                "relationship": link.get(
                    "relationship",
                    "Caregiver",
                ),
                "status": link["status"],
                "created_at": link.get("created_at"),
            }
        )

    return result


@app.put(
    "/caregiver/links/{link_id}/accept"
)
def accept_caregiver_link(
    link_id: str,
    patient: dict = Depends(get_my_patient),
) -> dict:
    """Patient accepts a caregiver request."""

    result = caregiver_links_collection.update_one(
        {
            "_id": object_id(
                link_id,
                "link ID",
            ),
            "patient_id": str(patient["_id"]),
            "status": "pending",
        },
        {
            "$set": {
                "status": "active",
                "accepted_at": now(),
            }
        },
    )

    if not result.modified_count:
        raise HTTPException(
            status_code=404,
            detail="Pending caregiver request not found",
        )

    return {
        "link_id": link_id,
        "patient_id": str(patient["_id"]),
        "status": "active",
    }


@app.get(
    "/caregiver/patients"
)
def caregiver_patients(
    current_user: dict = Depends(get_current_user),
) -> list[dict]:
    """Return all patients linked to the caregiver."""

    if current_user["role"] != "caregiver":
        raise HTTPException(
            status_code=403,
            detail="Caregiver role required",
        )

    links = caregiver_links_collection.find(
        {
            "caregiver_id": current_user["user_id"],
            "status": "active",
        }
    )

    result = []

    for link in links:
        patient = patients_collection.find_one(
            {
                "_id": object_id(
                    link["patient_id"],
                    "patient ID",
                )
            }
        )

        if patient:
            result.append(
                {
                    "patient": serialise(patient),
                    "patient_id": link["patient_id"],
                    "relationship": link.get(
                        "relationship",
                        "Caregiver",
                    ),
                    "analytics": patient_analytics(
                        link["patient_id"]
                    ),
                }
            )

    return result


@app.get(
    "/caregiver/my-requests",
)
def caregiver_my_requests(
    current_user: dict = Depends(get_current_user),
) -> list[dict]:
    """Return pending link requests sent by this caregiver."""

    if current_user["role"] != "caregiver":
        raise HTTPException(
            status_code=403,
            detail="Caregiver role required",
        )

    links = caregiver_links_collection.find(
        {
            "caregiver_id": current_user["user_id"],
            "status": "pending",
        }
    )

    result = []

    for link in links:
        patient = patients_collection.find_one(
            {
                "_id": object_id(
                    link["patient_id"],
                    "patient ID",
                )
            }
        )

        result.append(
            {
                "link_id": str(link["_id"]),
                "patient_id": link["patient_id"],
                "patient_name": (
                    patient.get("name")
                    if patient
                    else "Patient"
                ),
                "relationship": link.get(
                    "relationship",
                    "Caregiver",
                ),
                "status": link["status"],
                "created_at": link.get("created_at"),
            }
        )

    return result


@app.get(
    "/caregiver/patients/{patient_id}"
)
@app.get(
    "/caregiver/patients/{patient_id}/analytics"
)
def caregiver_patient(
    patient_id: str,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Return one linked patient's dashboard data."""

    if current_user["role"] != "caregiver":
        raise HTTPException(
            status_code=403,
            detail="Caregiver role required",
        )

    link = caregiver_links_collection.find_one(
        {
            "caregiver_id": current_user["user_id"],
            "patient_id": patient_id,
            "status": "active",
        }
    )

    if not link:
        raise HTTPException(
            status_code=403,
            detail="Patient is not linked to this caregiver",
        )

    patient = patients_collection.find_one(
        {
            "_id": object_id(
                patient_id,
                "patient ID",
            )
        }
    )

    if not patient:
        raise HTTPException(
            status_code=404,
            detail="Patient not found",
        )

    return {
        "patient": serialise(patient),
        "analytics": patient_analytics(
            patient_id
        ),
        "profile": save_profile(
            patient_id
        ),
    }


# ============================================================
# MEMORY MOMENTS
# ============================================================

def _caregiver_owns_memory(
    memory_id: str,
    current_user: dict,
) -> dict:
    """Verify the caregiver owns this memory and return it."""

    if current_user["role"] != "caregiver":
        raise HTTPException(
            status_code=403,
            detail="Only caregivers can manage memories",
        )

    memory = memories_collection.find_one(
        {
            "_id": object_id(
                memory_id,
                "memory ID",
            ),
            "created_by": current_user["user_id"],
        }
    )

    if not memory:
        raise HTTPException(
            status_code=404,
            detail="Memory not found",
        )

    return memory


@app.post(
    "/memories",
    status_code=status.HTTP_201_CREATED,
)
def create_memory(
    body: MemoryCreate,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Caregiver creates a memory capsule for a patient."""

    if current_user["role"] != "caregiver":
        raise HTTPException(
            status_code=403,
            detail="Only caregivers can create memories",
        )

    patient_id = body.patient_id.strip()

    patient_object_id = object_id(
        patient_id,
        "patient ID",
    )

    patient = patients_collection.find_one(
        {
            "_id": patient_object_id,
        }
    )

    if not patient:
        raise HTTPException(
            status_code=404,
            detail="Patient not found",
        )

    link = caregiver_links_collection.find_one(
        {
            "caregiver_id": current_user["user_id"],
            "patient_id": patient_id,
            "status": "active",
        }
    )

    if not link:
        raise HTTPException(
            status_code=403,
            detail="Patient is not linked to this caregiver",
        )

    result = memories_collection.insert_one(
        {
            "patient_id": patient_id,
            "created_by": current_user["user_id"],
            "title": body.title,
            "description": body.description,
            "photos": [],
            "people": body.people,
            "place": body.place,
            "year": body.year,
            "voice": None,
            "tags": body.tags,
            "priority": body.priority,
            "active": True,
            "shown_count": 0,
            "last_shown_at": None,
            "created_at": now(),
        }
    )

    return {
        "memory_id": str(result.inserted_id),
        "patient_id": patient_id,
        "title": body.title,
        "status": "created",
    }


@app.get(
    "/memories",
)
def list_memories(
    patient_id: str = Query(...),
    current_user: dict = Depends(get_current_user),
) -> list[dict]:
    """List all memories for a patient.

    Caregivers can see all memories they created.
    Patients can see their own active memories.
    """

    patient_id = patient_id.strip()

    object_id(
        patient_id,
        "patient ID",
    )

    if current_user["role"] == "caregiver":
        links = caregiver_links_collection.find_one(
            {
                "caregiver_id": current_user["user_id"],
                "patient_id": patient_id,
                "status": "active",
            }
        )

        if not links:
            raise HTTPException(
                status_code=403,
                detail="Patient is not linked to this caregiver",
            )

        query = {
            "patient_id": patient_id,
            "created_by": current_user["user_id"],
        }

    elif current_user["role"] == "elderly":
        patient = patients_collection.find_one(
            {
                "_id": object_id(
                    patient_id,
                    "patient ID",
                ),
                "user_id": current_user["user_id"],
            }
        )

        if not patient:
            raise HTTPException(
                status_code=403,
                detail="Access denied",
            )

        query = {
            "patient_id": patient_id,
            "active": True,
        }

    else:
        raise HTTPException(
            status_code=403,
            detail="Access denied",
        )

    memories = memories_collection.find(
        query
    ).sort(
        "created_at",
        -1,
    )

    return [
        serialise(m)
        for m in memories
    ]


@app.get(
    "/memories/today",
)
def get_today_memory(
    patient_id: str = Query(...),
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Return today's memory moment for a patient.

    Uses a simple resurfacing algorithm:
    1. Active memories only.
    2. Avoid recently shown memories.
    3. Prefer higher priority.
    4. Random among candidates.
    """

    patient_id = patient_id.strip()

    object_id(
        patient_id,
        "patient ID",
    )

    patient = patients_collection.find_one(
        {
            "_id": object_id(
                patient_id,
                "patient ID",
            ),
        }
    )

    if not patient:
        raise HTTPException(
            status_code=404,
            detail="Patient not found",
        )

    if current_user["role"] == "caregiver":
        link = caregiver_links_collection.find_one(
            {
                "caregiver_id": current_user["user_id"],
                "patient_id": patient_id,
                "status": "active",
            }
        )

        if not link:
            raise HTTPException(
                status_code=403,
                detail="Patient is not linked to this caregiver",
            )

    elif current_user["role"] == "elderly":
        if patient.get("user_id") != current_user["user_id"]:
            raise HTTPException(
                status_code=403,
                detail="Access denied",
            )

    else:
        raise HTTPException(
            status_code=403,
            detail="Access denied",
        )

    all_memories = list(
        memories_collection.find(
            {
                "patient_id": patient_id,
                "active": True,
            }
        )
    )

    if not all_memories:
        return {
            "memory": None,
            "message": "No memories yet. Ask your caregiver to add some.",
        }

    yesterday = now() - timedelta(days=1)

    candidates = [
        m for m in all_memories
        if m.get("last_shown_at") is None
        or m["last_shown_at"] < yesterday
    ]

    if not candidates:
        candidates = all_memories

    candidates.sort(
        key=lambda m: (
            -(m.get("priority", 0)),
            m.get("shown_count", 0),
        )
    )

    top_priority = candidates[0].get("priority", 0)

    best = [
        m for m in candidates
        if m.get("priority", 0) == top_priority
    ]

    chosen = random.choice(best)

    memories_collection.update_one(
        {
            "_id": chosen["_id"],
        },
        {
            "$set": {
                "last_shown_at": now(),
            },
            "$inc": {
                "shown_count": 1,
            },
        },
    )

    return {
        "memory": serialise(chosen),
    }


@app.get(
    "/memories/{memory_id}",
)
def get_memory(
    memory_id: str,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Get a single memory capsule."""

    memory = memories_collection.find_one(
        {
            "_id": object_id(
                memory_id,
                "memory ID",
            ),
        }
    )

    if not memory:
        raise HTTPException(
            status_code=404,
            detail="Memory not found",
        )

    patient_id = memory["patient_id"]

    if current_user["role"] == "caregiver":
        link = caregiver_links_collection.find_one(
            {
                "caregiver_id": current_user["user_id"],
                "patient_id": patient_id,
                "status": "active",
            }
        )

        if not link and memory.get("created_by") != current_user["user_id"]:
            raise HTTPException(
                status_code=403,
                detail="Access denied",
            )

    elif current_user["role"] == "elderly":
        patient = patients_collection.find_one(
            {
                "_id": object_id(
                    patient_id,
                    "patient ID",
                ),
            }
        )

        if not patient or patient.get("user_id") != current_user["user_id"]:
            raise HTTPException(
                status_code=403,
                detail="Access denied",
            )

        if not memory.get("active", False):
            raise HTTPException(
                status_code=404,
                detail="Memory not found",
            )

    else:
        raise HTTPException(
            status_code=403,
            detail="Access denied",
        )

    return serialise(memory)


@app.put(
    "/memories/{memory_id}",
)
def update_memory(
    memory_id: str,
    body: MemoryUpdate,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Caregiver updates a memory capsule."""

    _caregiver_owns_memory(
        memory_id,
        current_user,
    )

    update_fields = {
        k: v
        for k, v in body.model_dump(
            exclude_unset=True,
        ).items()
        if v is not None
    }

    if not update_fields:
        raise HTTPException(
            status_code=400,
            detail="No fields to update",
        )

    memories_collection.update_one(
        {
            "_id": object_id(
                memory_id,
                "memory ID",
            ),
        },
        {
            "$set": update_fields,
        },
    )

    return {
        "memory_id": memory_id,
        "status": "updated",
    }


@app.delete(
    "/memories/{memory_id}",
)
def delete_memory(
    memory_id: str,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Caregiver soft-deletes a memory capsule."""

    _caregiver_owns_memory(
        memory_id,
        current_user,
    )

    memories_collection.update_one(
        {
            "_id": object_id(
                memory_id,
                "memory ID",
            ),
        },
        {
            "$set": {
                "active": False,
            },
        },
    )

    return {
        "memory_id": memory_id,
        "status": "removed",
    }


@app.post(
    "/memories/{memory_id}/interact",
)
def memory_interaction(
    memory_id: str,
    action: str = Query(
        ...,
        pattern="^(viewed|listened|tell_me_more|next)$",
    ),
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Track patient interaction with a memory.

    This helps the resurfacing algorithm understand
    which memories the patient engages with.
    """

    memory = memories_collection.find_one(
        {
            "_id": object_id(
                memory_id,
                "memory ID",
            ),
        }
    )

    if not memory:
        raise HTTPException(
            status_code=404,
            detail="Memory not found",
        )

    patient_id = memory["patient_id"]

    if current_user["role"] == "elderly":
        patient = patients_collection.find_one(
            {
                "_id": object_id(
                    patient_id,
                    "patient ID",
                ),
            }
        )

        if not patient or patient.get("user_id") != current_user["user_id"]:
            raise HTTPException(
                status_code=403,
                detail="Access denied",
            )

    memory_interactions_collection.insert_one(
        {
            "memory_id": memory_id,
            "patient_id": patient_id,
            "action": action,
            "timestamp": now(),
        }
    )

    return {
        "status": "recorded",
    }


# ============================================================
# JOURNEY ASSIST
# ============================================================

import math

DESTINATION_RADIUS_M = 100
ARRIVAL_RADIUS_M = 50
MIN_PROMPT_INTERVAL_MIN = 15


def _haversine_m(
    lat1: float,
    lon1: float,
    lat2: float,
    lon2: float,
) -> float:
    """Return distance in metres between two lat/lng points."""

    R = 6_371_000

    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)

    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)

    a = (
        math.sin(dphi / 2) ** 2
        + math.cos(phi1)
        * math.cos(phi2)
        * math.sin(dlam / 2) ** 2
    )

    return R * 2 * math.atan2(
        math.sqrt(a),
        math.sqrt(1 - a),
    )


def _caregiver_can_access_patient(
    patient_id: str,
    user_id: str,
) -> bool:
    """Check if a caregiver has an active link to a patient."""

    link = caregiver_links_collection.find_one(
        {
            "caregiver_id": user_id,
            "patient_id": patient_id,
            "status": "active",
        }
    )
    return link is not None


@app.post(
    "/journeys",
    status_code=status.HTTP_201_CREATED,
)
def create_journey(
    body: JourneyCreate,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Caregiver creates a journey for a linked patient."""

    if current_user["role"] != "caregiver":
        raise HTTPException(
            status_code=403,
            detail="Only caregivers can create journeys",
        )

    patient_id = body.patient_id.strip()
    object_id(patient_id, "patient ID")

    patient = patients_collection.find_one(
        {"_id": object_id(patient_id, "patient ID")}
    )

    if not patient:
        raise HTTPException(
            status_code=404,
            detail="Patient not found",
        )

    if not _caregiver_can_access_patient(
        patient_id,
        current_user["user_id"],
    ):
        raise HTTPException(
            status_code=403,
            detail="Patient is not linked to this caregiver",
        )

    result = journeys_collection.insert_one(
        {
            "patient_id": patient_id,
            "caregiver_id": current_user["user_id"],
            "destination_name": body.destination_name,
            "destination_address": body.destination_address,
            "destination_latitude": body.destination_latitude,
            "destination_longitude": body.destination_longitude,
            "purpose": body.purpose,
            "expected_duration_minutes": body.expected_duration_minutes,
            "status": "active",
            "started_at": now(),
            "arrival_at": None,
            "completed_at": None,
            "last_latitude": None,
            "last_longitude": None,
            "last_location_at": None,
            "last_prompt_at": None,
            "distance_to_destination_m": None,
            "created_at": now(),
        }
    )

    return {
        "journey_id": str(result.inserted_id),
        "patient_id": patient_id,
        "destination_name": body.destination_name,
        "purpose": body.purpose,
        "status": "active",
    }


@app.get(
    "/journeys/active",
)
def get_active_journey(
    patient_id: str = Query(default=None),
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Return the active journey for a patient.

    If patient_id is provided, used by caregivers.
    If not, used by the patient themselves.
    """

    if current_user["role"] == "elderly":
        patient = patients_collection.find_one(
            {"user_id": current_user["user_id"]}
        )
        if not patient:
            raise HTTPException(
                status_code=404,
                detail="Patient profile not found",
            )
        pid = str(patient["_id"])

    elif current_user["role"] == "caregiver":
        if not patient_id:
            raise HTTPException(
                status_code=400,
                detail="patient_id required for caregiver",
            )
        pid = patient_id.strip()

        if not _caregiver_can_access_patient(
            pid,
            current_user["user_id"],
        ):
            raise HTTPException(
                status_code=403,
                detail="Patient is not linked to this caregiver",
            )
    else:
        raise HTTPException(
            status_code=403,
            detail="Access denied",
        )

    journey = journeys_collection.find_one(
        {
            "patient_id": pid,
            "status": {"$in": ["active", "near_destination", "arrived"]},
        },
        sort=[("created_at", -1)],
    )

    if not journey:
        return {"journey": None}

    return {
        "journey": serialise(journey),
    }


@app.get(
    "/journeys/{journey_id}",
)
def get_journey(
    journey_id: str,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Get a specific journey."""

    journey = journeys_collection.find_one(
        {"_id": object_id(journey_id, "journey ID")}
    )

    if not journey:
        raise HTTPException(
            status_code=404,
            detail="Journey not found",
        )

    pid = journey["patient_id"]

    if current_user["role"] == "elderly":
        patient = patients_collection.find_one(
            {"user_id": current_user["user_id"]}
        )
        if not patient or str(patient["_id"]) != pid:
            raise HTTPException(
                status_code=403,
                detail="Access denied",
            )

    elif current_user["role"] == "caregiver":
        if not _caregiver_can_access_patient(
            pid,
            current_user["user_id"],
        ):
            raise HTTPException(
                status_code=403,
                detail="Access denied",
            )
    else:
        raise HTTPException(
            status_code=403,
            detail="Access denied",
        )

    return serialise(journey)


@app.post(
    "/journeys/{journey_id}/location",
)
def update_journey_location(
    journey_id: str,
    body: JourneyLocationUpdate,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Patient sends their current GPS location."""

    journey = journeys_collection.find_one(
        {"_id": object_id(journey_id, "journey ID")}
    )

    if not journey:
        raise HTTPException(
            status_code=404,
            detail="Journey not found",
        )

    pid = journey["patient_id"]

    if current_user["role"] == "elderly":
        patient = patients_collection.find_one(
            {"user_id": current_user["user_id"]}
        )
        if not patient or str(patient["_id"]) != pid:
            raise HTTPException(
                status_code=403,
                detail="Access denied",
            )
    else:
        raise HTTPException(
            status_code=403,
            detail="Only the patient can send location updates",
        )

    if journey["status"] not in ("active", "near_destination"):
        return {
            "status": journey["status"],
            "message": "Journey is no longer active.",
        }

    dist = _haversine_m(
        body.latitude,
        body.longitude,
        journey["destination_latitude"],
        journey["destination_longitude"],
    )

    new_status = "active"
    arrival_at = journey.get("arrival_at")

    if dist <= ARRIVAL_RADIUS_M:
        new_status = "arrived"
        if arrival_at is None:
            arrival_at = now()
    elif dist <= DESTINATION_RADIUS_M:
        new_status = "near_destination"

    update_fields = {
        "last_latitude": body.latitude,
        "last_longitude": body.longitude,
        "last_location_at": now(),
        "distance_to_destination_m": round(dist),
        "status": new_status,
    }

    if arrival_at is not None:
        update_fields["arrival_at"] = arrival_at

    journeys_collection.update_one(
        {"_id": journey["_id"]},
        {"$set": update_fields},
    )

    return {
        "status": new_status,
        "distance_to_destination_m": round(dist),
    }


@app.post(
    "/journeys/{journey_id}/complete",
)
def complete_journey(
    journey_id: str,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Mark a journey as completed."""

    journey = journeys_collection.find_one(
        {"_id": object_id(journey_id, "journey ID")}
    )

    if not journey:
        raise HTTPException(
            status_code=404,
            detail="Journey not found",
        )

    pid = journey["patient_id"]

    if current_user["role"] == "caregiver":
        if not _caregiver_can_access_patient(
            pid,
            current_user["user_id"],
        ):
            raise HTTPException(
                status_code=403,
                detail="Access denied",
            )
    elif current_user["role"] == "elderly":
        patient = patients_collection.find_one(
            {"user_id": current_user["user_id"]}
        )
        if not patient or str(patient["_id"]) != pid:
            raise HTTPException(
                status_code=403,
                detail="Access denied",
            )
    else:
        raise HTTPException(
            status_code=403,
            detail="Access denied",
        )

    journeys_collection.update_one(
        {"_id": journey["_id"]},
        {
            "$set": {
                "status": "completed",
                "completed_at": now(),
            }
        },
    )

    return {
        "journey_id": journey_id,
        "status": "completed",
    }


@app.post(
    "/journeys/{journey_id}/cancel",
)
def cancel_journey(
    journey_id: str,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Cancel an active journey."""

    journey = journeys_collection.find_one(
        {"_id": object_id(journey_id, "journey ID")}
    )

    if not journey:
        raise HTTPException(
            status_code=404,
            detail="Journey not found",
        )

    pid = journey["patient_id"]

    if current_user["role"] == "caregiver":
        if not _caregiver_can_access_patient(
            pid,
            current_user["user_id"],
        ):
            raise HTTPException(
                status_code=403,
                detail="Access denied",
            )
    elif current_user["role"] == "elderly":
        patient = patients_collection.find_one(
            {"user_id": current_user["user_id"]}
        )
        if not patient or str(patient["_id"]) != pid:
            raise HTTPException(
                status_code=403,
                detail="Access denied",
            )
    else:
        raise HTTPException(
            status_code=403,
            detail="Access denied",
        )

    journeys_collection.update_one(
        {"_id": journey["_id"]},
        {
            "$set": {
                "status": "cancelled",
                "completed_at": now(),
            }
        },
    )

    return {
        "journey_id": journey_id,
        "status": "cancelled",
    }


# ============================================================
# FAMILY RECOGNITION
# ============================================================

@app.get(
    "/family-members",
    tags=["Family Recognition"],
)
def list_family_members(
    patient_id: str = Query(...),
    current_user: dict = Depends(get_current_user),
):
    """List all family members for a patient."""
    if current_user["role"] == "caregiver":
        if not _caregiver_can_access_patient(
            patient_id, current_user["user_id"]
        ):
            raise HTTPException(status_code=403, detail="Access denied")
    elif current_user["role"] == "elderly":
        patient = patients_collection.find_one(
            {"user_id": current_user["user_id"]}
        )
        if not patient or str(patient["_id"]) != patient_id:
            raise HTTPException(status_code=403, detail="Access denied")
    else:
        raise HTTPException(status_code=403, detail="Access denied")

    members = list(
        family_members_collection.find(
            {"patient_id": patient_id, "active": True}
        ).sort("priority", -1)
    )

    return {
        "family_members": [serialise(m) for m in members],
        "count": len(members),
    }


@app.post(
    "/family-members",
    tags=["Family Recognition"],
    status_code=status.HTTP_201_CREATED,
)
def create_family_member(
    body: FamilyMemberCreate,
    current_user: dict = Depends(get_current_user),
):
    """Create a new family member profile (caregiver only)."""
    if current_user["role"] != "caregiver":
        raise HTTPException(
            status_code=403,
            detail="Only caregivers can add family members",
        )

    if not _caregiver_can_access_patient(
        body.patient_id, current_user["user_id"]
    ):
        raise HTTPException(
            status_code=403,
            detail="Patient is not linked to this caregiver",
        )

    result = family_members_collection.insert_one(
        {
            "patient_id": body.patient_id,
            "caregiver_id": current_user["user_id"],
            "name": body.name,
            "relationship": body.relationship,
            "description": body.description,
            "voice_description": body.voice_description,
            "photo_url": body.photo_url,
            "nicknames": body.nicknames,
            "how_you_know_them": body.how_you_know_them,
            "fun_fact": body.fun_fact,
            "priority": body.priority,
            "active": True,
            "created_at": now(),
            "updated_at": now(),
        }
    )

    return {
        "family_member_id": str(result.inserted_id),
        "name": body.name,
        "relationship": body.relationship,
    }


@app.get(
    "/family-members/{member_id}",
    tags=["Family Recognition"],
)
def get_family_member(
    member_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Get a single family member by ID."""
    member = family_members_collection.find_one(
        {"_id": ObjectId(member_id)}
    )

    if not member:
        raise HTTPException(
            status_code=404, detail="Family member not found"
        )

    if current_user["role"] == "caregiver":
        if member.get("caregiver_id") != current_user["user_id"]:
            raise HTTPException(status_code=403, detail="Access denied")
    elif current_user["role"] == "elderly":
        patient = patients_collection.find_one(
            {"user_id": current_user["user_id"]}
        )
        if not patient or str(patient["_id"]) != member.get("patient_id"):
            raise HTTPException(status_code=403, detail="Access denied")
    else:
        raise HTTPException(status_code=403, detail="Access denied")

    return {"family_member": serialise(member)}


@app.put(
    "/family-members/{member_id}",
    tags=["Family Recognition"],
)
def update_family_member(
    member_id: str,
    body: FamilyMemberUpdate,
    current_user: dict = Depends(get_current_user),
):
    """Update a family member (caregiver only)."""
    if current_user["role"] != "caregiver":
        raise HTTPException(
            status_code=403,
            detail="Only caregivers can update family members",
        )

    member = family_members_collection.find_one(
        {"_id": ObjectId(member_id)}
    )

    if not member:
        raise HTTPException(
            status_code=404, detail="Family member not found"
        )

    if member.get("caregiver_id") != current_user["user_id"]:
        raise HTTPException(status_code=403, detail="Access denied")

    update_fields = {}
    for field in [
        "name", "relationship", "description",
        "voice_description", "photo_url", "nicknames",
        "how_you_know_them", "fun_fact", "priority",
    ]:
        value = getattr(body, field, None)
        if value is not None:
            update_fields[field] = value

    if update_fields:
        update_fields["updated_at"] = now()
        family_members_collection.update_one(
            {"_id": member["_id"]},
            {"$set": update_fields},
        )

    return {"status": "updated"}


@app.delete(
    "/family-members/{member_id}",
    tags=["Family Recognition"],
)
def delete_family_member(
    member_id: str,
    current_user: dict = Depends(get_current_user),
):
    """Soft-delete a family member (caregiver only)."""
    if current_user["role"] != "caregiver":
        raise HTTPException(
            status_code=403,
            detail="Only caregivers can delete family members",
        )

    member = family_members_collection.find_one(
        {"_id": ObjectId(member_id)}
    )

    if not member:
        raise HTTPException(
            status_code=404, detail="Family member not found"
        )

    if member.get("caregiver_id") != current_user["user_id"]:
        raise HTTPException(status_code=403, detail="Access denied")

    family_members_collection.update_one(
        {"_id": member["_id"]},
        {"$set": {"active": False, "updated_at": now()}},
    )

    return {"status": "deleted"}