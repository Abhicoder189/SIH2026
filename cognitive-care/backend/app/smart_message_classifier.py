"""
Smart Message Understanding - ML Message Classifier

Provides message relevance and category classification.

COLD-START STRATEGY:
- When real training data is insufficient (< 30 samples), uses rule-based baseline
- ML layer becomes active only with real anonymized interaction data
- Never generates fake patient data for training

RULE-BASED BASELINE:
- Keyword matching for relevance
- Keyword scoring for category
- Pattern matching for common message formats

ML PIPELINE (when data exists):
- GradientBoostingClassifier for relevance
- GradientBoostingClassifier for category
- Features: message statistics, keyword density, patterns
"""

from __future__ import annotations

import hashlib
import math
import os
import pickle
import re
from typing import Any

# Lazy import ML libraries only when needed
_sklearn_available = False
try:
    import numpy as np
    from sklearn.ensemble import GradientBoostingClassifier
    from sklearn.feature_extraction.text import TfidfVectorizer
    _sklearn_available = True
except ImportError:
    np = None  # type: ignore
    GradientBoostingClassifier = None  # type: ignore
    TfidfVectorizer = None  # type: ignore


# ============================================================
# CONSTANTS
# ============================================================

MIN_TRAINING_SAMPLES = 30
MODEL_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "ml_models")
RELEVANCE_MODEL_PATH = os.path.join(MODEL_DIR, "message_relevance_classifier.joblib")
CATEGORY_MODEL_PATH = os.path.join(MODEL_DIR, "message_category_classifier.joblib")

# Irrelevance patterns - messages matching these are NOT relevant
IRRELEVANCE_PATTERNS = [
    re.compile(r"\b(otp|one\s*time\s*password)\s*[:\-]?\s*\d{4,6}\b", re.I),
    re.compile(r"\b(congratulations?|you\s+won|winner|prize|lottery)\b", re.I),
    re.compile(r"\b(\d+%\s*(off|discount|sale))\b", re.I),
    re.compile(r"\b(unsubscribe|opt\s*out|stop\s+messages?)\b", re.I),
    re.compile(r"\b(click\s+here|claim\s+now|act\s+now|hurry)\b", re.I),
    re.compile(r"\b(account\s+balance|available\s+balance|closing\s+balance)\b", re.I),
    re.compile(r"\b(debit|credit)\s+(of|for)\s+INR\s*\d+\b", re.I),
    re.compile(r"\b(transacted|debited|credited)\b", re.I),
    re.compile(r"\b(email\s+verification|verify\s+your|confirm\s+your)\b", re.I),
    re.compile(r"\b(special\s+offer|limited\s+time|exclusive\s+deal)\b", re.I),
    re.compile(r"\b(follow\s+us|like\s+our|download\s+our\s+app)\b", re.I),
]

# Relevance patterns - messages matching these ARE likely relevant
RELEVANCE_PATTERNS = [
    re.compile(r"\b(due\s+(date|on|by)|pay\s+(by|before|on|at)|payment\s+(due|deadline))\b", re.I),
    re.compile(r"\b(appointment\s+(at|on|with|tomorrow|today))\b", re.I),
    re.compile(r"\b(medicines?\s+(are\s+)?ready|prescription|pharmacy)\b", re.I),
    re.compile(r"\b(train|bus|flight)\s+(departs?|leaves?|at|on)\b", re.I),
    re.compile(r"\b(delivery\s+(on|by|today|tomorrow|arriving))\b", re.I),
    re.compile(r"\b(go\s+to|visit|reach|arrive\s+at)\b", re.I),
    re.compile(r"\b(reminder|remember|don't\s+forget)\b", re.I),
    re.compile(r"\b(dr\.|doctor|hospital|clinic)\b", re.I),
]

# Category keyword groups
CATEGORY_KEYWORDS: dict[str, list[str]] = {
    "BILL": [
        "bill", "payment", "due", "invoice", "pay", "amount",
        "electricity", "water", "gas", "rent", "phone", "internet",
        "recharge", "credit card", "emi", "billing",
    ],
    "MEDICINE": [
        "medicine", "medication", "prescription", "pharmacy", "drug",
        "tablet", "capsule", "pickup", "ready for", "refill",
        "apollo", "chemist", "dose", "dose",
    ],
    "HEALTHCARE_APPOINTMENT": [
        "appointment", "doctor", "consultation", "visit", "checkup",
        "opd", "clinic", "hospital", "dr.", "dr ", "see dr",
        "surgery", "operation", "test", "lab", "scan",
    ],
    "TRAVEL": [
        "train", "bus", "flight", "ticket", "platform", "station",
        "depart", "leave", "travel", "journey", "boarding", "pnr",
        "seat", "coach", "route",
    ],
    "DELIVERY": [
        "delivery", "courier", "package", "parcel", "shipped",
        "track", "dispatch", "arriving", "delivered",
    ],
    "SHOPPING": [
        "order", "purchase", "bought", "shopping", "store",
        "market", "buy", "cart", "checkout",
    ],
    "FAMILY_INSTRUCTION": [
        "mama", "papa", "dada", "nana", "nani", "dadi", "bua",
        "uncle", "aunt", "brother", "sister", "son", "daughter",
        "family", "relative",
    ],
}


# ============================================================
# RULE-BASED CLASSIFIER (COLD START)
# ============================================================


def classify_relevance_rule_based(message: str) -> tuple[bool, float]:
    """
    Rule-based relevance classification.

    Returns (is_relevant, confidence).
    """

    msg = message.strip()
    if not msg or len(msg) < 5:
        return False, 0.9

    for pattern in IRRELEVANCE_PATTERNS:
        if pattern.search(msg):
            return False, 0.85

    relevance_score = 0
    for pattern in RELEVANCE_PATTERNS:
        if pattern.search(msg):
            relevance_score += 1

    keyword_score = 0
    msg_lower = msg.lower()
    for cat_keywords in CATEGORY_KEYWORDS.values():
        for kw in cat_keywords:
            if kw in msg_lower:
                keyword_score += 1

    has_amount = bool(re.search(r"[\u20b9$€£]\s*\d+", msg))
    has_date = bool(re.search(
        r"\b(\d{1,2}\s*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)|"
        r"(tomorrow|today|next\s+\w+day))\b", msg, re.I
    ))
    has_time = bool(re.search(r"\b\d{1,2}\s*(am|pm|:)\d*\b", msg, re.I))

    if has_amount:
        relevance_score += 1
    if has_date:
        relevance_score += 1
    if has_time:
        relevance_score += 0.5

    if relevance_score >= 3:
        return True, min(0.6 + relevance_score * 0.05, 0.85)
    elif relevance_score >= 1 and keyword_score >= 2:
        return True, min(0.5 + keyword_score * 0.05, 0.75)
    elif keyword_score >= 3:
        return True, min(0.5 + keyword_score * 0.03, 0.7)
    elif relevance_score == 0 and keyword_score == 0:
        return False, 0.6

    return False, 0.5


def classify_category_rule_based(message: str) -> tuple[str, float]:
    """
    Rule-based category classification.

    Returns (category, confidence).
    """

    msg_lower = message.lower().strip()

    scores: dict[str, float] = {}
    for category, keywords in CATEGORY_KEYWORDS.items():
        score = sum(1 for kw in keywords if kw in msg_lower)
        if score > 0:
            scores[category] = score

    if not scores:
        return "OTHER", 0.4

    best_category = max(scores, key=scores.get)
    best_score = scores[best_category]

    total = sum(scores.values())
    confidence = min(0.5 + (best_score / max(total, 1)) * 0.3 + best_score * 0.02, 0.8)

    return best_category, confidence


# ============================================================
# ML-BASED CLASSIFIER
# ============================================================


def _extract_features(message: str) -> list[float]:
    """Extract numeric features from a message for ML classification."""

    msg = message.strip()
    msg_lower = msg.lower()

    features = [
        float(len(msg)),
        float(len(msg.split())),
        float(msg.count("?")),
        float(msg.count("!")),
        float(msg.count(".")),
        float(1 if re.search(r"[\u20b9$€£]", msg) else 0),
        float(1 if re.search(r"\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}", msg) else 0),
        float(1 if re.search(r"\d{1,2}\s*(am|pm)", msg, re.I) else 0),
        float(1 if re.search(r"\d{1,2}:\d{2}", msg) else 0),
    ]

    for cat, keywords in CATEGORY_KEYWORDS.items():
        count = sum(1 for kw in keywords if kw in msg_lower)
        features.append(float(count))

    action_verbs = ["pay", "buy", "visit", "go", "call", "pick", "attend", "remember"]
    features.extend([float(v in msg_lower) for v in action_verbs])

    urgency_words = ["urgent", "immediately", "asap", "now", "hurry", "deadline"]
    features.append(float(sum(1 for w in urgency_words if w in msg_lower)))

    politeness = ["please", "kindly", "request", "thank"]
    features.append(float(sum(1 for w in politeness if w in msg_lower)))

    return features


def train_relevance_classifier(
    messages: list[str],
    labels: list[bool],
) -> bool:
    """
    Train the relevance classifier on real data.

    Returns True if training succeeded.
    """

    if not _sklearn_available:
        return False

    if len(messages) < MIN_TRAINING_SAMPLES:
        return False

    try:
        features = [_extract_features(msg) for msg in messages]
        X = np.array(features)
        y = np.array(labels)

        model = GradientBoostingClassifier(
            n_estimators=50,
            max_depth=4,
            learning_rate=0.1,
            random_state=42,
        )
        model.fit(X, y)

        os.makedirs(MODEL_DIR, exist_ok=True)
        with open(RELEVANCE_MODEL_PATH, "wb") as f:
            pickle.dump(model, f)

        return True
    except Exception:
        return False


def train_category_classifier(
    messages: list[str],
    labels: list[str],
) -> bool:
    """
    Train the category classifier on real data.

    Returns True if training succeeded.
    """

    if not _sklearn_available:
        return False

    if len(messages) < MIN_TRAINING_SAMPLES:
        return False

    unique_labels = set(labels)
    if len(unique_labels) < 2:
        return False

    try:
        features = [_extract_features(msg) for msg in messages]
        X = np.array(features)
        y = np.array(labels)

        model = GradientBoostingClassifier(
            n_estimators=50,
            max_depth=4,
            learning_rate=0.1,
            random_state=42,
        )
        model.fit(X, y)

        os.makedirs(MODEL_DIR, exist_ok=True)
        with open(CATEGORY_MODEL_PATH, "wb") as f:
            pickle.dump(model, f)

        return True
    except Exception:
        return False


def classify_relevance_ml(message: str) -> tuple[bool, float] | None:
    """
    ML-based relevance classification.

    Returns (is_relevant, confidence) or None if model not available.
    """

    if not _sklearn_available or not os.path.exists(RELEVANCE_MODEL_PATH):
        return None

    try:
        with open(RELEVANCE_MODEL_PATH, "rb") as f:
            model = pickle.load(f)

        features = _extract_features(message)
        X = np.array([features])

        prediction = model.predict(X)[0]
        probabilities = model.predict_proba(X)[0]
        confidence = float(max(probabilities))

        return bool(prediction), confidence
    except Exception:
        return None


def classify_category_ml(message: str) -> tuple[str, float] | None:
    """
    ML-based category classification.

    Returns (category, confidence) or None if model not available.
    """

    if not _sklearn_available or not os.path.exists(CATEGORY_MODEL_PATH):
        return None

    try:
        with open(CATEGORY_MODEL_PATH, "rb") as f:
            model = pickle.load(f)

        features = _extract_features(message)
        X = np.array([features])

        prediction = model.predict(X)[0]
        probabilities = model.predict_proba(X)[0]
        confidence = float(max(probabilities))

        return str(prediction), confidence
    except Exception:
        return None


# ============================================================
# UNIFIED CLASSIFIER
# ============================================================


def classify_message(message: str) -> dict[str, Any]:
    """
    Classify a message for relevance and category.

    Uses ML if model exists, otherwise falls back to rules.
    Returns a dict with:
        - is_relevant: bool
        - relevance_confidence: float
        - category: str
        - category_confidence: float
        - method: "ml" or "rule_based"
    """

    ml_relevance = classify_relevance_ml(message)
    if ml_relevance is not None:
        is_relevant, rel_conf = ml_relevance
        method = "ml"
    else:
        is_relevant, rel_conf = classify_relevance_rule_based(message)
        method = "rule_based"

    if is_relevant:
        ml_category = classify_category_ml(message)
        if ml_category is not None:
            category, cat_conf = ml_category
        else:
            category, cat_conf = classify_category_rule_based(message)
    else:
        category = "OTHER"
        cat_conf = 0.9

    return {
        "is_relevant": is_relevant,
        "relevance_confidence": round(rel_conf, 2),
        "category": category,
        "category_confidence": round(cat_conf, 2),
        "method": method,
    }


def get_fingerprint(message: str, source: str | None = None) -> str:
    """
    Generate a deterministic fingerprint for duplicate detection.

    Uses normalized source + normalized message to create a hash.
    Prevents processing the same message multiple times.
    """

    normalized_source = (source or "").lower().strip()
    normalized_msg = re.sub(r"\s+", " ", message.lower().strip())

    combined = f"{normalized_source}|{normalized_msg}"

    return hashlib.sha256(combined.encode()).hexdigest()[:32]
