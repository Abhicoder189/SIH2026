"""
Caregiver Instruction Parser.

Uses Gemini to extract structured task information
from natural language caregiver instructions.

CRITICAL RULES:
- The LLM only extracts information that is present in the text.
- It NEVER invents destinations, tasks, or medical instructions.
- If something is ambiguous, it returns null for that field.
"""

from __future__ import annotations

import json
import os
import re
from typing import Any

from dotenv import load_dotenv
from google import genai

load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_MODEL = os.getenv("GEMINI_VOICE_MODEL", "gemini-2.5-flash")


# ============================================================
# FALLBACK PARSER (deterministic, no LLM)
# ============================================================


def _fallback_parse(instruction: str) -> dict[str, Any]:
    """
    Simple deterministic parser when Gemini is unavailable.
    Extracts basic structure from the instruction text.
    """

    text = instruction.strip()
    text_lower = text.lower()

    purpose = ""
    steps: list[str] = []

    if " and " in text_lower:
        parts = re.split(r'\s+and\s+', text, maxsplit=1, flags=re.IGNORECASE)
        if len(parts) == 2:
            purpose = parts[1].strip().rstrip(".")
    elif text_lower.startswith("go to"):
        after_goto = re.sub(r'^go\s+to\s+[^,]+,?\s*', '', text, flags=re.IGNORECASE).strip()
        if after_goto:
            purpose = after_goto.rstrip(".")
    else:
        purpose = text.rstrip(".")

    if purpose:
        action_lower = purpose.lower()
        if "buy" in action_lower or "purchase" in action_lower:
            steps = ["Enter the store", "Find the item", "Purchase the item"]
        elif "pay" in action_lower:
            steps = ["Find the billing counter", "Pay the bill"]
        elif "deposit" in action_lower:
            steps = ["Find the deposit counter", "Deposit the item"]
        elif "pick up" in action_lower or "collect" in action_lower:
            steps = ["Go to the counter", "Collect the item"]
        elif "appointment" in action_lower:
            steps = ["Go to reception", "Wait for your turn", "See the doctor"]

    return {
        "task_type": _guess_task_type(text_lower),
        "purpose": purpose,
        "object": _guess_object(text_lower),
        "action": _guess_action(text_lower),
        "steps": steps,
        "internal_location_hint": "",
    }


def _guess_task_type(text: str) -> str:
    if any(w in text for w in ["buy", "purchase", "shop"]):
        return "purchase"
    if any(w in text for w in ["pay", "bill", "payment"]):
        return "bill_payment"
    if any(w in text for w in ["deposit"]):
        return "deposit"
    if any(w in text for w in ["collect", "pick up", "pickup"]):
        return "pickup"
    if any(w in text for w in ["appointment", "doctor", "hospital"]):
        return "appointment"
    if any(w in text for w in ["meeting", "office"]):
        return "meeting"
    return "errand"


def _guess_object(text: str) -> str:
    objects = [
        "medicine", "medicines", "prescription", "cheque", "check",
        "electricity bill", "water bill", "bill", "document",
        "letter", "package", "food", "groceries",
    ]
    for obj in objects:
        if obj in text:
            return obj
    return ""


def _guess_action(text: str) -> str:
    actions = ["buy", "pay", "deposit", "collect", "pick up", "deliver"]
    for action in actions:
        if action in text:
            return action
    return ""


# ============================================================
# GEMINI-BASED PARSER
# ============================================================


def parse_instruction(instruction: str) -> dict[str, Any]:
    """
    Parse a caregiver's natural language instruction
    into structured task information.

    Returns:
        {
            "task_type": "bill_payment",
            "purpose": "pay the electricity bill",
            "object": "electricity bill",
            "action": "pay",
            "steps": ["Find billing counter", "Pay electricity bill"],
            "internal_location_hint": "billing counter"
        }
    """

    if not instruction or not instruction.strip():
        return {
            "task_type": "errand",
            "purpose": "",
            "object": "",
            "action": "",
            "steps": [],
            "internal_location_hint": "",
        }

    if not GEMINI_API_KEY:
        return _fallback_parse(instruction)

    try:
        client = genai.Client(api_key=GEMINI_API_KEY)

        prompt = f"""
You are a structured information extractor for a
dementia assistance application.

A caregiver has written an instruction for a patient.
Extract ONLY the information explicitly present in the text.

INSTRUCTION:
"{instruction}"

Extract these fields:
- task_type: one of [purchase, bill_payment, deposit, pickup, appointment, meeting, errand]
- purpose: what the patient needs to do (short phrase, extracted from text)
- object: the thing being acted upon (e.g., "medicines", "electricity bill", "cheque")
- action: the action verb (e.g., "buy", "pay", "deposit", "collect")
- steps: ordered list of concrete steps the patient should follow inside/near the destination
- internal_location_hint: any specific indoor location mentioned (e.g., "billing counter", "pharmacy counter"). Empty string if not mentioned.

CRITICAL RULES:
1. Only extract information that is EXPLICITLY stated in the instruction.
2. Do NOT invent steps that are not implied by the instruction.
3. Do NOT invent indoor locations that are not mentioned.
4. If the instruction only says "Go to X and do Y", the steps should be minimal.
5. Keep purpose as a short natural phrase.

Return ONLY valid JSON:
{{
    "task_type": "...",
    "purpose": "...",
    "object": "...",
    "action": "...",
    "steps": ["...", "..."],
    "internal_location_hint": "..."
}}
"""

        response_schema = {
            "type": "OBJECT",
            "properties": {
                "task_type": {"type": "STRING"},
                "purpose": {"type": "STRING"},
                "object": {"type": "STRING"},
                "action": {"type": "STRING"},
                "steps": {
                    "type": "ARRAY",
                    "items": {"type": "STRING"},
                },
                "internal_location_hint": {"type": "STRING"},
            },
            "required": [
                "task_type", "purpose", "object",
                "action", "steps", "internal_location_hint",
            ],
        }

        result = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
            config={
                "response_mime_type": "application/json",
                "response_schema": response_schema,
                "temperature": 0.1,
            },
        )

        raw = getattr(result, "text", "") or ""
        raw = raw.strip()
        raw = re.sub(r"^```(?:json)?\s*", "", raw, flags=re.IGNORECASE)
        raw = re.sub(r"\s*```$", "", raw)

        parsed = json.loads(raw)

        if not isinstance(parsed, dict):
            raise ValueError("Invalid response type")

        return {
            "task_type": str(parsed.get("task_type", "errand")),
            "purpose": str(parsed.get("purpose", "")),
            "object": str(parsed.get("object", "")),
            "action": str(parsed.get("action", "")),
            "steps": parsed.get("steps", []) if isinstance(parsed.get("steps"), list) else [],
            "internal_location_hint": str(parsed.get("internal_location_hint", "")),
        }

    except Exception:
        return _fallback_parse(instruction)
