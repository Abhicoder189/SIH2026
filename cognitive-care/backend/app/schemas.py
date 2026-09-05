from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

Role = Literal["elderly", "caregiver", "health_worker"]
GameType = Literal["memory", "pattern", "attention"]
ReminderType = Literal["medicine", "hydration", "meal", "exercise", "game", "appointment", "activity"]

class UserRegister(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    email: str = Field(..., min_length=5, max_length=150)
    password: str = Field(..., min_length=8, max_length=72)
    role: Role = "elderly"
    age: int = Field(default=60, ge=1, le=120)
    language: str = Field(default="English", min_length=2, max_length=50)
    region: str | None = Field(default=None, max_length=80)

class UserLogin(BaseModel):
    email: str = Field(..., min_length=5, max_length=150)
    password: str = Field(..., min_length=1, max_length=100)

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    role: Role

class PatientCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    age: int = Field(..., ge=1, le=120)
    language: str = Field(..., min_length=2, max_length=50)
    region: str | None = Field(default=None, max_length=80)

class GameStart(BaseModel):
    patient_id: str
    difficulty: int = Field(default=1, ge=1, le=5)

class GameSubmit(BaseModel):
    patient_id: str
    game_session_id: str
    reaction_time: float = Field(..., ge=0, le=3600)
    hints_used: int = Field(default=0, ge=0, le=20)

class MemoryGameSubmit(GameSubmit):
    selected_objects: list[str] = Field(default_factory=list, max_length=12)

class PatternGameSubmit(GameSubmit):
    answer: str = Field(..., min_length=1, max_length=30)

class AttentionGameSubmit(GameSubmit):
    answer: int = Field(..., ge=0, le=100)

class ReminderCreate(BaseModel):
    patient_id: str
    title: str = Field(..., min_length=2, max_length=120)
    message: str = Field(default="", max_length=300)
    type: ReminderType
    scheduled_time: datetime
    repeat: str = Field(default="none", pattern="^(none|daily|weekly)$")

class ReminderUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=120)
    message: str | None = Field(default=None, max_length=300)
    scheduled_time: datetime | None = None
    repeat: str | None = Field(default=None, pattern="^(none|daily|weekly)$")
    completed: bool | None = None
    snooze_minutes: int | None = Field(default=None, ge=1, le=1440)

class CaregiverLinkCreate(BaseModel):
    patient_id: str
    relationship: str = Field(..., min_length=2, max_length=80)

class SyncAttempt(BaseModel):
    client_event_id: str = Field(..., min_length=8, max_length=128)
    game_type: GameType
    patient_id: str
    game_session_id: str | None = None
    score: float = Field(..., ge=0)
    max_score: float = Field(..., gt=0)
    accuracy: float = Field(..., ge=0, le=100)
    reaction_time: float = Field(..., ge=0, le=3600)
    hints_used: int = Field(default=0, ge=0, le=20)
    difficulty: int = Field(..., ge=1, le=5)
    completed_at: datetime

class SyncReminder(BaseModel):
    client_event_id: str = Field(..., min_length=8, max_length=128)
    reminder_id: str
    completed: bool
    occurred_at: datetime


# ============================================================
# MEMORY MOMENTS
# ============================================================

class MemoryCreate(BaseModel):
    patient_id: str
    title: str = Field(..., min_length=2, max_length=150)
    description: str = Field(default="", max_length=500)
    people: list[str] = Field(default_factory=list, max_length=20)
    place: str = Field(default="", max_length=150)
    year: int | None = Field(default=None, ge=1900, le=2100)
    tags: list[str] = Field(default_factory=list, max_length=10)
    priority: int = Field(default=0, ge=0, le=10)


class MemoryUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=150)
    description: str | None = Field(default=None, max_length=500)
    people: list[str] | None = None
    place: str | None = Field(default=None, max_length=150)
    year: int | None = Field(default=None, ge=1900, le=2100)
    tags: list[str] | None = None
    priority: int | None = Field(default=None, ge=0, le=10)
    active: bool | None = None


# ============================================================
# JOURNEY ASSIST
# ============================================================

class JourneyCreate(BaseModel):
    patient_id: str
    destination_name: str = Field(..., min_length=2, max_length=150)
    destination_address: str = Field(default="", max_length=300)
    destination_latitude: float = Field(..., ge=-90, le=90)
    destination_longitude: float = Field(..., ge=-180, le=180)
    purpose: str = Field(..., min_length=2, max_length=300)
    expected_duration_minutes: int = Field(default=45, ge=5, le=480)

class JourneyLocationUpdate(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)


# ============================================================
# FAMILY RECOGNITION
# ============================================================

class FamilyMemberCreate(BaseModel):
    patient_id: str
    name: str = Field(..., min_length=1, max_length=100)
    relationship: str = Field(..., min_length=1, max_length=80)
    description: str = Field(default="", max_length=500)
    voice_description: str = Field(default="", max_length=500)
    photo_url: str = Field(default="", max_length=500)
    nicknames: list[str] = Field(default_factory=list, max_length=10)
    how_you_know_them: str = Field(default="", max_length=500)
    fun_fact: str = Field(default="", max_length=300)
    priority: int = Field(default=0, ge=0, le=10)


class FamilyMemberUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    relationship: str | None = Field(default=None, min_length=1, max_length=80)
    description: str | None = Field(default=None, max_length=500)
    voice_description: str | None = Field(default=None, max_length=500)
    photo_url: str | None = Field(default=None, max_length=500)
    nicknames: list[str] | None = None
    how_you_know_them: str | None = Field(default=None, max_length=500)
    fun_fact: str | None = Field(default=None, max_length=300)
    priority: int | None = Field(default=None, ge=0, le=10)
