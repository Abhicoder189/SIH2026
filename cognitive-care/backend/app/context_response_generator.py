"""
Contextual Response Generator for dementia assistance.

Generates short, clear, reassuring responses based
on trusted context only. NEVER invents information.
"""

from __future__ import annotations

from typing import Any


# ============================================================
# RESPONSE PRIORITY
# ============================================================
#
# When the patient asks WHY_AM_I_HERE:
#   1. Active task purpose
#   2. Caregiver instruction
#   3. Current step
#   4. Destination name only
#
# Never fabricate a purpose.
# ============================================================


def generate_response(
    context: dict[str, Any],
    query_type: str = "WHY_AM_I_HERE",
) -> str:
    """
    Generate a dementia-friendly response for the given query.

    query_type options:
    - WHY_AM_I_HERE
    - WHERE_AM_I
    - WHAT_DO_I_DO_NEXT
    - IM_CONFUSED
    - ARRIVAL_GREETING
    - PROACTIVE_PROMPT
    """

    dest = context.get("destination", {})
    task = context.get("task", {})
    journey = context.get("journey", {})

    dest_name = dest.get("name", "your destination")
    purpose = task.get("purpose", "")
    instruction = task.get("instruction", "")
    current_step = task.get("current_step_text", "")
    next_step = task.get("next_step_text", "")
    state = journey.get("state", "TRAVELLING")

    if query_type == "WHY_AM_I_HERE":
        return _why_am_i_here(dest_name, purpose, instruction, current_step)

    if query_type == "WHERE_AM_I":
        return _where_am_i(dest_name, purpose, state)

    if query_type == "WHAT_DO_I_DO_NEXT":
        return _what_next(dest_name, purpose, next_step, state)

    if query_type == "IM_CONFUSED":
        return _im_confused(dest_name, purpose, state)

    if query_type == "ARRIVAL_GREETING":
        return _arrival_greeting(dest_name, purpose, next_step)

    if query_type == "PROACTIVE_PROMPT":
        return _proactive_prompt(dest_name, purpose, state, next_step)

    return "I am here to help you."


# ============================================================
# RESPONSE GENERATORS
# ============================================================


def _why_am_i_here(
    dest_name: str,
    purpose: str,
    instruction: str,
    current_step: str,
) -> str:
    """Answer: WHY AM I HERE?"""

    if purpose:
        return f"You are here to {purpose}."

    if instruction:
        return f"Your instruction: {instruction}"

    if dest_name:
        return f"You are at {dest_name}."

    return "You are currently on a journey."


def _where_am_i(
    dest_name: str,
    purpose: str,
    state: str,
) -> str:
    """Answer: WHERE AM I?"""

    if state == "ARRIVED":
        if purpose:
            return f"You have reached {dest_name}. You are here to {purpose}."
        return f"You have reached {dest_name}."

    if state == "APPROACHING":
        if purpose:
            return f"You are close to {dest_name}. You are going there to {purpose}."
        return f"You are close to {dest_name}."

    if purpose:
        return f"You are on your way to {dest_name}. You are going there to {purpose}."

    return f"You are on your way to {dest_name}."


def _what_next(
    dest_name: str,
    purpose: str,
    next_step: str,
    state: str,
) -> str:
    """Answer: WHAT SHOULD I DO NEXT?"""

    if state == "ARRIVED":
        if next_step:
            return f"Please {next_step}."
        if purpose:
            return f"You are here to {purpose}."
        return f"You have arrived at {dest_name}."

    if state == "APPROACHING":
        return f"You are almost at {dest_name}. Please continue."

    return f"You are on your way to {dest_name}. Please continue."


def _im_confused(
    dest_name: str,
    purpose: str,
    state: str,
) -> str:
    """Answer: I'M CONFUSED — provide reassurance."""

    parts = ["You are safe."]

    if state == "ARRIVED":
        parts.append(f"You have reached {dest_name}.")
    elif state == "APPROACHING":
        parts.append(f"You are close to {dest_name}.")
    else:
        parts.append(f"You are on your way to {dest_name}.")

    if purpose:
        parts.append(f"You came here to {purpose}.")

    return " ".join(parts)


def _arrival_greeting(
    dest_name: str,
    purpose: str,
    next_step: str,
) -> str:
    """Proactively greet patient on arrival."""

    parts = [f"You have reached {dest_name}."]

    if purpose:
        parts.append(f"You are here to {purpose}.")

    if next_step:
        parts.append(f"Please {next_step}.")

    return " ".join(parts)


def _proactive_prompt(
    dest_name: str,
    purpose: str,
    state: str,
    next_step: str,
) -> str:
    """Proactive gentle prompt when patient may need help."""

    if state == "ARRIVED":
        if purpose:
            return f"Reminder: You are at {dest_name} to {purpose}."
        return f"You are at {dest_name}."

    if state == "APPROACHING":
        return f"You are almost at {dest_name}."

    return ""


# ============================================================
# PUBLIC HELPER — get context for API response
# ============================================================


def get_all_responses(context: dict[str, Any]) -> dict[str, str]:
    """Generate all possible responses for the Flutter UI."""

    return {
        "why_am_i_here": generate_response(context, "WHY_AM_I_HERE"),
        "where_am_i": generate_response(context, "WHERE_AM_I"),
        "what_next": generate_response(context, "WHAT_DO_I_DO_NEXT"),
        "im_confused": generate_response(context, "IM_CONFUSED"),
        "arrival_greeting": generate_response(context, "ARRIVAL_GREETING"),
        "proactive_prompt": generate_response(context, "PROACTIVE_PROMPT"),
    }
