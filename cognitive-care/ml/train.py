"""Train an optional difficulty-recommendation model from exported attempts.

This model only recommends a game difficulty. It must never be used for a
medical diagnosis or prognosis. The API continues to use rule-based adaptation
when no validated model exists.
"""
from pathlib import Path
import json

import joblib
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score
from sklearn.model_selection import train_test_split

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data" / "cognitive_training_data.csv"
MODEL_DIR = ROOT / "model"
FEATURES = ["memory_score", "attention_score", "pattern_score", "average_accuracy", "average_reaction_time", "average_hints", "average_performance", "current_difficulty", "trend"]


def main() -> None:
    if not DATA.exists():
        raise SystemExit(f"Training data not found: {DATA}. Run backend/create_dataset.py after collecting consented game attempts.")
    frame = pd.read_csv(DATA)
    required = set(FEATURES + ["target_difficulty"])
    if len(frame) < 30 or not required.issubset(frame.columns):
        raise SystemExit("At least 30 valid, consented training rows are required before training.")
    x, y = frame[FEATURES], frame["target_difficulty"]
    x_train, x_test, y_train, y_test = train_test_split(x, y, test_size=0.2, random_state=42, stratify=y if y.nunique() > 1 else None)
    model = RandomForestClassifier(n_estimators=200, random_state=42, class_weight="balanced")
    model.fit(x_train, y_train)
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    joblib.dump({"model": model, "features": FEATURES}, MODEL_DIR / "difficulty_recommender.joblib")
    (MODEL_DIR / "metrics.json").write_text(json.dumps({"rows": len(frame), "validation_accuracy": round(accuracy_score(y_test, model.predict(x_test)), 3)}, indent=2), encoding="utf-8")
    print("Model and validation metrics saved to", MODEL_DIR)


if __name__ == "__main__":
    main()
