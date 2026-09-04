"""Optional, local predictor. Callers must use rule-based fallback if absent."""
from pathlib import Path
import joblib

MODEL = Path(__file__).resolve().parent / "model" / "difficulty_recommender.joblib"


def recommend(features: dict) -> int | None:
    if not MODEL.exists():
        return None
    bundle = joblib.load(MODEL)
    row = [[features.get(name, 0) for name in bundle["features"]]]
    return int(bundle["model"].predict(row)[0])
