"""
Gemini-powered voice command interpreter.

Gemini only decides WHICH safe action is intended.
It never directly executes application actions.
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

ALLOWED_INTENTS = {
    "start_memory",
    "start_attention",
    "start_pattern",
    "read_reminders",
    "help",
    "repeat",
    "unknown",
}


def _fallback_response(text: str, language: str) -> dict[str, str]:
    """
    Safe fallback when Gemini is unavailable.
    """

    value = text.lower().strip()

    if any(
        phrase in value
        for phrase in [
            "memory game",
            "memory test",
            "play memory",
            "remembering game",
        ]
    ):
        return {
            "intent": "start_memory",
            "response": "Sure. Let's start a memory game.",
            "language": language,
        }

    if any(
        phrase in value
        for phrase in [
            "attention game",
            "concentration game",
            "focus game",
            "play attention",
        ]
    ):
        return {
            "intent": "start_attention",
            "response": "Sure. Let's start an attention game.",
            "language": language,
        }

    if any(
        phrase in value
        for phrase in [
            "pattern game",
            "pattern test",
            "play pattern",
        ]
    ):
        return {
            "intent": "start_pattern",
            "response": "Sure. Let's start a pattern game.",
            "language": language,
        }

    if any(
        phrase in value
        for phrase in [
            "reminder",
            "reminders",
            "what do i need to do",
            "what should i do",
        ]
    ):
        return {
            "intent": "read_reminders",
            "response": "I'll show your reminders.",
            "language": language,
        }

    if any(
        phrase in value
        for phrase in [
            "help",
            "what can you do",
            "how can you help",
        ]
    ):
        return {
            "intent": "help",
            "response": (
                "I can start memory, attention and pattern games, "
                "and help you check reminders."
            ),
            "language": language,
        }

    if any(
        phrase in value
        for phrase in [
            "repeat",
            "say that again",
            "again please",
        ]
    ):
        return {
            "intent": "repeat",
            "response": "I'll repeat that.",
            "language": language,
        }

    return {
        "intent": "unknown",
        "response": (
            "Sorry, I could not understand that. "
            "Please try again."
        ),
        "language": language,
    }


def _clean_history(
    history: list[dict[str, str]] | None,
) -> list[dict[str, str]]:
    """Keep only safe, useful conversation history."""

    if not isinstance(history, list):
        return []

    cleaned: list[dict[str, str]] = []

    for item in history[-10:]:
        if not isinstance(item, dict):
            continue

        role = str(item.get("role", "")).lower().strip()
        content = str(item.get("content", "")).strip()

        if role not in {"user", "assistant"}:
            continue

        if not content:
            continue

        cleaned.append(
            {
                "role": role,
                "content": content[:500],
            }
        )

    return cleaned


def interpret_voice_command(
    text: str,
    preferred_language: str = "en",
    history: list[dict[str, str]] | None = None,
) -> dict[str, str]:
    """
    Convert natural language into one safe application intent.

    Gemini is used only for interpretation.
    """

    language = preferred_language.lower().strip() or "en"

    if not text.strip():
        return {
            "intent": "unknown",
            "response": "Please say something.",
            "language": language,
        }

    if not GEMINI_API_KEY:
        return _fallback_response(text, language)

    try:
        client = genai.Client(api_key=GEMINI_API_KEY)

        conversation = _clean_history(history)

        history_text = ""

        for message in conversation:
            history_text += (
                f"{message['role']}: "
                f"{message['content']}\n"
            )

        prompt = f"""
You are the voice assistant for Cognitive Care,
an elderly-friendly cognitive gaming and memory assistance
application.

Your job is ONLY to understand the user's request and select
ONE safe application intent.

You must NOT diagnose dementia.
You must NOT provide medical diagnosis.
You must NOT invent medication instructions.
You must NOT directly execute any action.

Available intents:

start_memory
- User wants to play a memory game.

start_attention
- User wants an attention, concentration, or focus game.

start_pattern
- User wants a pattern recognition game.

read_reminders
- User wants to hear or see reminders or today's tasks.

help
- User asks what the assistant can do.

repeat
- User asks the assistant to repeat the previous response.

unknown
- Anything that does not clearly match the above.

Preferred language:
{language}

Previous conversation:
{history_text}

Current user message:
{text}

Return ONLY valid JSON with exactly these fields:

{{
  "intent": "one allowed intent",
  "response": "short friendly response",
  "language": "{language}"
}}

Rules:
1. Never return an intent outside the allowed list.
2. Do not execute actions.
3. Keep responses short and elderly-friendly.
4. If the request is ambiguous, use "unknown".
5. Preserve the preferred language where possible.
"""

        response_schema = {
            "type": "OBJECT",
            "properties": {
                "intent": {
                    "type": "STRING",
                    "enum": sorted(ALLOWED_INTENTS),
                },
                "response": {
                    "type": "STRING",
                },
                "language": {
                    "type": "STRING",
                },
            },
            "required": [
                "intent",
                "response",
                "language",
            ],
        }

        result = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
            config={
                "response_mime_type": "application/json",
                "response_schema": response_schema,
                "temperature": 0.2,
            },
        )

        raw = getattr(result, "text", "") or ""
        raw = raw.strip()

        # Remove accidental markdown fences.
        raw = re.sub(
            r"^```(?:json)?\s*",
            "",
            raw,
            flags=re.IGNORECASE,
        )
        raw = re.sub(
            r"\s*```$",
            "",
            raw,
        )

        parsed: Any = json.loads(raw)

        if not isinstance(parsed, dict):
            raise ValueError("Gemini returned invalid JSON.")

        intent = str(parsed.get("intent", "unknown"))

        if intent not in ALLOWED_INTENTS:
            intent = "unknown"

        response_text = str(
            parsed.get(
                "response",
                "Sorry, I could not understand that.",
            )
        ).strip()

        if not response_text:
            response_text = (
                "Sorry, I could not understand that."
            )

        response_language = str(
            parsed.get("language", language)
        ).strip() or language

        return {
            "intent": intent,
            "response": response_text,
            "language": response_language,
        }

    except Exception:
        return _fallback_response(text, language)