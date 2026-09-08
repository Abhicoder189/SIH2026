"""
Smart Message Understanding - Event Extractor

Extracts structured events from raw messages using Gemini AI
with deterministic fallback when AI is unavailable.

SAFETY RULES:
- NEVER invent information not present in the message
- NEVER diagnose medical conditions
- NEVER modify medication dosages
- NEVER create fictional bills, appointments, or locations
- If information is missing, return null for that field
- Confidence reflects extraction certainty
"""

from __future__ import annotations

import json
import os
import re
from datetime import datetime, timezone
from typing import Any

from google import genai


# ============================================================
# GEMINI STRUCTURED EVENT EXTRACTION
# ============================================================

_EXTRACTION_PROMPT = """You are a message understanding system for elderly dementia patients.
Extract structured information from the message below.

You MUST return ONLY valid JSON matching this exact schema:
{
    "category": "BILL" | "MEDICINE" | "HEALTHCARE_APPOINTMENT" | "TRAVEL" | "DELIVERY" | "SHOPPING" | "FAMILY_INSTRUCTION" | "REMINDER" | "EVENT" | "OTHER",
    "title": "short human-readable title",
    "action": "PAY" | "PICKUP" | "ATTEND" | "VISIT" | "BUY" | "CALL" | "REMEMBER" | "OTHER",
    "purpose": "short description of what needs to be done",
    "amount": number or null,
    "currency": "INR" | "USD" | null,
    "due_date": "YYYY-MM-DD" or null,
    "due_time": "HH:MM" or null,
    "appointment_time": "YYYY-MM-DD HH:MM" or null,
    "location_name": "name of place" or null,
    "location_address": "full address" or null,
    "doctor_name": "Dr. ..." or null,
    "medicine_name": "name of medicine" or null,
    "sender": "sender identifier" or null,
    "steps": ["step 1", "step 2"] or [],
    "confidence": 0.0 to 1.0,
    "is_relevant": true or false
}

RULES:
1. Only extract information PRESENT in the message. Do NOT invent.
2. If a field is not mentioned, set it to null (or empty list for steps).
3. Dates should be relative to today: {today}.
4. "is_relevant" = false for OTPs, spam, marketing, account balance alerts.
5. "confidence" reflects how certain you are about the extraction.
6. NEVER include medical advice, dosage changes, or diagnostic information.
7. For medicine messages: extract medicine_name but NOT dosage unless explicitly stated.
8. Keep title under 50 characters. Keep purpose under 100 characters.

Message:
\"\"\"{message}\"\"\"

Return ONLY the JSON object. No explanation."""

_EXTRACTOR_SCHEMA = {
    "type": "object",
    "properties": {
        "category": {"type": "string", "enum": [
            "BILL", "MEDICINE", "HEALTHCARE_APPOINTMENT", "TRAVEL",
            "DELIVERY", "SHOPPING", "FAMILY_INSTRUCTION", "REMINDER",
            "EVENT", "OTHER"
        ]},
        "title": {"type": "string"},
        "action": {"type": "string", "enum": [
            "PAY", "PICKUP", "ATTEND", "VISIT", "BUY", "CALL", "REMEMBER", "OTHER"
        ]},
        "purpose": {"type": "string"},
        "amount": {"type": ["number", "null"]},
        "currency": {"type": ["string", "null"]},
        "due_date": {"type": ["string", "null"]},
        "due_time": {"type": ["string", "null"]},
        "appointment_time": {"type": ["string", "null"]},
        "location_name": {"type": ["string", "null"]},
        "location_address": {"type": ["string", "null"]},
        "doctor_name": {"type": ["string", "null"]},
        "medicine_name": {"type": ["string", "null"]},
        "sender": {"type": ["string", "null"]},
        "steps": {"type": "array", "items": {"type": "string"}},
        "confidence": {"type": "number"},
        "is_relevant": {"type": "boolean"},
    },
    "required": [
        "category", "title", "action", "purpose", "confidence", "is_relevant"
    ],
}


def extract_event_from_message(
    message: str,
    sender: str | None = None,
    patient_age: int | None = None,
    patient_language: str | None = None,
) -> dict[str, Any] | None:
    """
    Extract structured event from a raw message using Gemini AI.

    Returns a structured event dict or None if extraction fails.
    NEVER returns fabricated data.
    """

    api_key = os.environ.get("GEMINI_API_KEY", "")
    if not api_key:
        return _deterministic_extract(message, sender)

    try:
        client = genai.Client(api_key=api_key)
        model_name = os.environ.get("GEMINI_VOICE_MODEL", "gemini-2.5-flash")

        today = datetime.now().strftime("%Y-%m-%d (%A)")
        prompt = _EXTRACTION_PROMPT.format(message=message, today=today)

        response = client.models.generate_content(
            model=model_name,
            contents=prompt,
            config={
                "temperature": 0.1,
                "max_output_tokens": 1024,
            },
        )

        text = response.text.strip()

        if text.startswith("```"):
            text = re.sub(r"^```(?:json)?\s*", "", text)
            text = re.sub(r"\s*```$", "", text)

        result = json.loads(text)

        if not isinstance(result, dict):
            return _deterministic_extract(message, sender)

        required_fields = ["category", "title", "action", "purpose", "confidence", "is_relevant"]
        for field in required_fields:
            if field not in result:
                return _deterministic_extract(message, sender)

        result["category"] = _validate_category(result["category"])
        result["action"] = _validate_action(result["action"])
        result["confidence"] = max(0.0, min(1.0, float(result.get("confidence", 0.5))))
        result["is_relevant"] = bool(result.get("is_relevant", True))

        if not result["is_relevant"]:
            result["confidence"] = max(result["confidence"], 0.8)

        result["sender"] = sender or result.get("sender")
        result["raw_message"] = message
        result["extraction_method"] = "gemini"

        return result

    except Exception:
        return _deterministic_extract(message, sender)


# ============================================================
# DETERMINISTIC FALLBACK EXTRACTION
# ============================================================

_BILL_KEYWORDS = [
    "bill", "payment", "due", "invoice", "amount", "pay",
    "electricity", "water", "gas", "rent", "phone", "internet",
    "recharge", "credit card", "emi",
]

_MEDICINE_KEYWORDS = [
    "medicine", "medication", "prescription", "pharmacy", "drug",
    "tablet", "capsule", "pickup", "ready for", "refill",
    "Apollo", "pharmacy", "chemist",
]

_APPOINTMENT_KEYWORDS = [
    "appointment", "doctor", "consultation", "visit", "checkup",
    "opd", "clinic", "hospital", "dr.", "dr ", "see dr",
]

_TRAVEL_KEYWORDS = [
    "train", "bus", "flight", "ticket", "platform", "station",
    "depart", "leave", "travel", "journey", "boarding",
]

_DELIVERY_KEYWORDS = [
    "delivery", "courier", "package", "parcel", "shipped",
    "track", "dispatch", "arriving",
]

_SHOPPING_KEYWORDS = [
    "order", "purchase", "bought", "shopping", "store",
    "market", "buy",
]

_ACTION_VERBS = {
    "pay": "PAY",
    "payment": "PAY",
    "buy": "BUY",
    "purchase": "BUY",
    "pick up": "PICKUP",
    "pickup": "PICKUP",
    "collect": "PICKUP",
    "attend": "ATTEND",
    "visit": "VISIT",
    "go to": "VISIT",
    "call": "CALL",
    "remember": "REMEMBER",
}

_CURRENCY_PATTERN = re.compile(r"[\u20b9$€£]|(?:Rs\.?|INR|USD|EUR|GBP)")
_AMOUNT_PATTERN = re.compile(r"[\u20b9$€£]?\s*(\d[\d,]*\.?\d*)")
_DATE_PATTERNS = [
    (re.compile(r"\b(\d{1,2})\s*(st|nd|rd|th)?\s*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*\b", re.I), "dmy"),
    (re.compile(r"\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*\s+(\d{1,2})(st|nd|rd|th)?\b", re.I), "mdy"),
    (re.compile(r"\b(\d{4})-(\d{1,2})-(\d{1,2})\b"), "iso"),
    (re.compile(r"\b(\d{1,2})/(\d{1,2})/(\d{4})\b"), "slash"),
    (re.compile(r"\btomorrow\b", re.I), "relative"),
    (re.compile(r"\bnext\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b", re.I), "relative"),
    (re.compile(r"\btonight\b", re.I), "relative"),
    (re.compile(r"\btoday\b", re.I), "relative"),
]

_TIME_PATTERN = re.compile(r"\b(\d{1,2}):(\d{2})\s*(am|pm)?\b", re.I)
_TIME_WORD_PATTERN = re.compile(r"\b(\d{1,2})\s*(am|pm)\b", re.I)

_LOCATION_KEYWORDS = [
    "office", "center", "centre", "hospital", "clinic", "pharmacy",
    "store", "shop", "station", "airport", "bank", "school",
    "counter", "desk", "hall", "building", "road", "street",
]


def _deterministic_extract(
    message: str,
    sender: str | None = None,
) -> dict[str, Any]:
    """
    Rule-based fallback extraction when Gemini is unavailable.
    NEVER invents information. Only uses what is explicitly in the message.
    """

    msg_lower = message.lower().strip()

    category = _classify_category(msg_lower)
    action = _extract_action(msg_lower)
    amount, currency = _extract_amount(message)
    due_date = _extract_date(msg_lower)
    due_time = _extract_time(msg_lower)
    location = _extract_location(msg_lower)
    title = _generate_title(category, msg_lower)
    purpose = _generate_purpose(category, action, msg_lower)

    confidence = 0.4

    if category != "OTHER":
        confidence += 0.15
    if due_date:
        confidence += 0.1
    if due_time:
        confidence += 0.05
    if amount:
        confidence += 0.1
    if location:
        confidence += 0.1
    if action != "OTHER":
        confidence += 0.1

    confidence = min(confidence, 0.85)

    is_relevant = category != "OTHER" or action != "OTHER"

    return {
        "category": category,
        "title": title,
        "action": action,
        "purpose": purpose,
        "amount": amount,
        "currency": currency,
        "due_date": due_date,
        "due_time": due_time,
        "appointment_time": None,
        "location_name": location,
        "location_address": None,
        "doctor_name": None,
        "medicine_name": None,
        "sender": sender,
        "steps": [],
        "confidence": confidence,
        "is_relevant": is_relevant,
        "raw_message": message,
        "extraction_method": "deterministic",
    }


def _classify_category(msg_lower: str) -> str:
    scores = {
        "BILL": sum(1 for kw in _BILL_KEYWORDS if kw in msg_lower),
        "MEDICINE": sum(1 for kw in _MEDICINE_KEYWORDS if kw in msg_lower),
        "HEALTHCARE_APPOINTMENT": sum(1 for kw in _APPOINTMENT_KEYWORDS if kw in msg_lower),
        "TRAVEL": sum(1 for kw in _TRAVEL_KEYWORDS if kw in msg_lower),
        "DELIVERY": sum(1 for kw in _DELIVERY_KEYWORDS if kw in msg_lower),
        "SHOPPING": sum(1 for kw in _SHOPPING_KEYWORDS if kw in msg_lower),
    }

    if not scores or max(scores.values()) == 0:
        return "OTHER"

    return max(scores, key=scores.get)


def _extract_action(msg_lower: str) -> str:
    for phrase, action in _ACTION_VERBS.items():
        if phrase in msg_lower:
            return action
    return "REMEMBER"


def _extract_amount(message: str) -> tuple[float | None, str | None]:
    currency_match = _CURRENCY_PATTERN.search(message)
    currency = "INR"
    if currency_match:
        sym = currency_match.group(0)
        if "$" in sym:
            currency = "USD"
        elif "€" in sym:
            currency = "EUR"
        elif "£" in sym:
            currency = "GBP"

    amount_match = _AMOUNT_PATTERN.search(message)
    if amount_match:
        try:
            amount_str = amount_match.group(1).replace(",", "")
            amount = float(amount_str)
            if amount > 0:
                return amount, currency
        except (ValueError, IndexError):
            pass

    return None, None


def _extract_date(msg_lower: str) -> str | None:
    for pattern, fmt in _DATE_PATTERNS:
        match = pattern.search(msg_lower)
        if match:
            if fmt == "relative":
                word = match.group(0).lower()
                now = datetime.now()
                if word == "tomorrow":
                    from datetime import timedelta
                    return (now + timedelta(days=1)).strftime("%Y-%m-%d")
                elif word == "today":
                    return now.strftime("%Y-%m-%d")
                elif word.startswith("next "):
                    day_name = word.replace("next ", "")
                    days = {
                        "monday": 0, "tuesday": 1, "wednesday": 2,
                        "thursday": 3, "friday": 4, "saturday": 5, "sunday": 6
                    }
                    target = days.get(day_name, 0)
                    from datetime import timedelta
                    current = now.weekday()
                    days_ahead = (target - current) % 7
                    if days_ahead == 0:
                        days_ahead = 7
                    return (now + timedelta(days=days_ahead)).strftime("%Y-%m-%d")
            elif fmt == "iso":
                try:
                    return f"{match.group(1)}-{int(match.group(2)):02d}-{int(match.group(3)):02d}"
                except (ValueError, IndexError):
                    pass
            elif fmt == "dmy":
                try:
                    month_map = {
                        "jan": 1, "feb": 2, "mar": 3, "apr": 4,
                        "may": 5, "jun": 6, "jul": 7, "aug": 8,
                        "sep": 9, "oct": 10, "nov": 11, "dec": 12,
                    }
                    day = int(match.group(1))
                    month_str = match.group(3)[:3].lower()
                    month = month_map.get(month_str, 0)
                    now = datetime.now()
                    if month:
                        return f"{now.year}-{month:02d}-{day:02d}"
                except (ValueError, IndexError):
                    pass
            elif fmt == "mdy":
                try:
                    month_map = {
                        "jan": 1, "feb": 2, "mar": 3, "apr": 4,
                        "may": 5, "jun": 6, "jul": 7, "aug": 8,
                        "sep": 9, "oct": 10, "nov": 11, "dec": 12,
                    }
                    month_str = match.group(1)[:3].lower()
                    day = int(match.group(2))
                    month = month_map.get(month_str, 0)
                    now = datetime.now()
                    if month:
                        return f"{now.year}-{month:02d}-{day:02d}"
                except (ValueError, IndexError):
                    pass

    return None


def _extract_time(msg_lower: str) -> str | None:
    match = _TIME_WORD_PATTERN.search(msg_lower)
    if match:
        hour = int(match.group(1))
        ampm = match.group(2).lower()
        if ampm == "pm" and hour < 12:
            hour += 12
        elif ampm == "am" and hour == 12:
            hour = 0
        if 0 <= hour <= 23:
            return f"{hour:02d}:00"

    match = _TIME_PATTERN.search(msg_lower)
    if match:
        hour = int(match.group(1))
        minute = int(match.group(2))
        ampm = match.group(3)
        if ampm:
            ampm = ampm.lower()
            if ampm == "pm" and hour < 12:
                hour += 12
            elif ampm == "am" and hour == 12:
                hour = 0
        if 0 <= hour <= 23 and 0 <= minute <= 59:
            return f"{hour:02d}:{minute:02d}"

    return None


def _extract_location(msg_lower: str) -> str | None:
    for kw in _LOCATION_KEYWORDS:
        if kw in msg_lower:
            idx = msg_lower.find(kw)
            start = max(0, idx - 40)
            snippet = msg_lower[start:idx + len(kw)]

            words = snippet.split()
            location_words = []
            for w in reversed(words[:-1]):
                if w in ("at", "to", "from", "in", "near", "the", "a", "an", "and", "or"):
                    break
                location_words.insert(0, w)

            if location_words:
                return " ".join(location_words).strip().title()

    return None


def _generate_title(category: str, msg_lower: str) -> str:
    if category == "BILL":
        for kw in ["electricity", "water", "gas", "phone", "internet", "rent", "credit card"]:
            if kw in msg_lower:
                return f"{kw.title()} Bill"
        return "Bill Payment"
    elif category == "MEDICINE":
        if "ready" in msg_lower or "pickup" in msg_lower:
            return "Medicine Pickup"
        return "Medicine Reminder"
    elif category == "HEALTHCARE_APPOINTMENT":
        if "doctor" in msg_lower or "dr." in msg_lower or "dr " in msg_lower:
            return "Doctor Appointment"
        return "Medical Appointment"
    elif category == "TRAVEL":
        if "train" in msg_lower:
            return "Train Journey"
        if "bus" in msg_lower:
            return "Bus Travel"
        if "flight" in msg_lower:
            return "Flight"
        return "Travel"
    elif category == "DELIVERY":
        return "Package Delivery"
    elif category == "SHOPPING":
        return "Shopping"
    elif category == "FAMILY_INSTRUCTION":
        return "Family Message"
    elif category == "REMINDER":
        return "Reminder"
    elif category == "EVENT":
        return "Event"
    return "Message"


def _generate_purpose(category: str, action: str, msg_lower: str) -> str:
    action_map = {
        "PAY": "Pay",
        "PICKUP": "Pick up",
        "ATTEND": "Attend",
        "VISIT": "Visit",
        "BUY": "Buy",
        "CALL": "Call",
        "REMEMBER": "Remember",
    }
    verb = action_map.get(action, "Handle")

    if category == "BILL":
        return f"{verb} bill"
    elif category == "MEDICINE":
        return f"{verb} medicines"
    elif category == "HEALTHCARE_APPOINTMENT":
        return f"{verb} appointment"
    elif category == "TRAVEL":
        return "Complete travel"
    elif category == "DELIVERY":
        return "Receive delivery"
    elif category == "SHOPPING":
        return f"{verb} items"
    return "Handle message"


def _validate_category(category: str) -> str:
    valid = [
        "BILL", "MEDICINE", "HEALTHCARE_APPOINTMENT", "TRAVEL",
        "DELIVERY", "SHOPPING", "FAMILY_INSTRUCTION", "REMINDER",
        "EVENT", "OTHER",
    ]
    cat = category.upper().strip()
    return cat if cat in valid else "OTHER"


def _validate_action(action: str) -> str:
    valid = ["PAY", "PICKUP", "ATTEND", "VISIT", "BUY", "CALL", "REMEMBER", "OTHER"]
    act = action.upper().strip()
    return act if act in valid else "OTHER"
