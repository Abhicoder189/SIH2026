import unittest

from app.adaptation import calculate_performance_score, recommend_difficulty
from app.analytics import analyze_patient_performance
from app.schemas import UserRegister
from app.task_context_engine import build_task_context, _derive_journey_state, _get_step_info
from app.context_response_generator import generate_response
from app.instruction_parser import _fallback_parse
from app.smart_message_classifier import (
    classify_relevance_rule_based,
    classify_category_rule_based,
    classify_message,
    get_fingerprint,
)
from app.smart_event_extractor import (
    _deterministic_extract,
    _extract_amount,
    _extract_date,
    _extract_time,
    _extract_location,
    _validate_category,
    _validate_action,
)


class CoreLogicTests(unittest.TestCase):
    def test_rule_based_difficulty_bounds(self):
        self.assertEqual(recommend_difficulty(5, 99), 5)
        self.assertEqual(recommend_difficulty(1, 0), 1)
        self.assertEqual(recommend_difficulty(3, 85), 4)

    def test_performance_rewards_accuracy(self):
        high = calculate_performance_score(100, 4, 0)
        low = calculate_performance_score(0, 40, 3)
        self.assertGreater(high, low)

    def test_analytics_reports_recent_trend(self):
        attempts = [
            {"accuracy": 50, "reaction_time": 20, "performance_score": 50, "next_difficulty": 1},
            {"accuracy": 60, "reaction_time": 15, "performance_score": 60, "next_difficulty": 2},
            {"accuracy": 90, "reaction_time": 5, "performance_score": 90, "next_difficulty": 3},
        ]
        report = analyze_patient_performance(attempts)
        self.assertEqual(report["trend"], "improving")
        self.assertEqual(report["current_difficulty"], 3)

    def test_registration_requires_a_strong_password(self):
        with self.assertRaises(ValueError):
            UserRegister(name="Asha", email="asha@example.com", password="short")


class TaskContextEngineTests(unittest.TestCase):

    def test_journey_state_derivation(self):
        self.assertEqual(_derive_journey_state("active", 600), "TRAVELLING")
        self.assertEqual(_derive_journey_state("active", 300), "APPROACHING")
        self.assertEqual(_derive_journey_state("active", 50), "APPROACHING")
        self.assertEqual(_derive_journey_state("active", 20), "ARRIVED")
        self.assertEqual(_derive_journey_state("arrived", 50), "ARRIVED")
        self.assertEqual(_derive_journey_state("completed", 0), "COMPLETED")
        self.assertEqual(_derive_journey_state("cancelled", 0), "CANCELLED")

    def test_step_info(self):
        steps = ["Enter store", "Find counter", "Pay bill"]
        info = _get_step_info(steps, 0)
        self.assertEqual(info["text"], "Enter store")
        self.assertEqual(info["next"], "Find counter")

        info2 = _get_step_info(steps, 2)
        self.assertEqual(info2["text"], "Pay bill")
        self.assertEqual(info2["next"], "")

    def test_empty_steps(self):
        info = _get_step_info([], 0)
        self.assertEqual(info["text"], "")
        self.assertEqual(info["next"], "")

    def test_build_task_context(self):
        journey = {
            "_id": "abc123",
            "destination_name": "Apollo Pharmacy",
            "destination_latitude": 28.6,
            "destination_longitude": 77.2,
            "destination_address": "123 Main St",
            "purpose": "buy medicines",
            "instruction": "Go to Apollo Pharmacy and buy medicines",
            "status": "active",
            "steps": ["Enter pharmacy", "Buy medicines"],
            "current_step": 0,
            "expected_duration_minutes": 30,
        }
        ctx = build_task_context(journey, 28.61, 77.21, 15.0)
        self.assertIn("location", ctx)
        self.assertIn("destination", ctx)
        self.assertIn("task", ctx)
        self.assertIn("journey", ctx)
        self.assertIn("assistance", ctx)
        self.assertEqual(ctx["destination"]["name"], "Apollo Pharmacy")
        self.assertEqual(ctx["task"]["purpose"], "buy medicines")

    def test_build_task_context_no_purpose(self):
        journey = {
            "_id": "def456",
            "destination_name": "Municipal Office",
            "destination_latitude": 28.5,
            "destination_longitude": 77.1,
            "purpose": "",
            "instruction": "",
            "status": "active",
            "steps": [],
            "current_step": 0,
        }
        ctx = build_task_context(journey)
        self.assertFalse(ctx["assistance"]["can_explain_purpose"])

    def test_response_generator_why_am_i_here_with_purpose(self):
        context = {
            "destination": {"name": "Apollo Pharmacy"},
            "task": {"purpose": "buy medicines", "instruction": "", "current_step_text": "", "next_step_text": ""},
            "journey": {"state": "ARRIVED"},
        }
        resp = generate_response(context, "WHY_AM_I_HERE")
        self.assertIn("buy medicines", resp)

    def test_response_generator_why_am_i_here_no_purpose(self):
        context = {
            "destination": {"name": "Municipal Office"},
            "task": {"purpose": "", "instruction": "", "current_step_text": "", "next_step_text": ""},
            "journey": {"state": "ARRIVED"},
        }
        resp = generate_response(context, "WHY_AM_I_HERE")
        self.assertIn("Municipal Office", resp)
        self.assertNotIn("bill", resp.lower())

    def test_response_generator_im_confused(self):
        context = {
            "destination": {"name": "Bank"},
            "task": {"purpose": "deposit cheque", "instruction": "", "current_step_text": "", "next_step_text": ""},
            "journey": {"state": "APPROACHING"},
        }
        resp = generate_response(context, "IM_CONFUSED")
        self.assertIn("safe", resp.lower())
        self.assertIn("Bank", resp)

    def test_fallback_instruction_parser(self):
        result = _fallback_parse("Go to the billing station and pay the electricity bill")
        self.assertEqual(result["task_type"], "bill_payment")
        self.assertIn("electricity bill", result["purpose"].lower())
        self.assertEqual(result["object"], "electricity bill")
        self.assertEqual(result["action"], "pay")

    def test_fallback_instruction_parser_buy(self):
        result = _fallback_parse("Go to Apollo Pharmacy and buy medicines")
        self.assertEqual(result["task_type"], "purchase")
        self.assertIn("medicines", result["purpose"].lower())


class SmartMessageClassifierTests(unittest.TestCase):

    def test_relevance_bill_message(self):
        is_relevant, confidence = classify_relevance_rule_based(
            "Electricity bill of Rs. 1240 is due on 15 September"
        )
        self.assertTrue(is_relevant)
        self.assertGreater(confidence, 0.5)

    def test_relevance_appointment_message(self):
        is_relevant, confidence = classify_relevance_rule_based(
            "Doctor appointment at City Hospital tomorrow at 10 AM"
        )
        self.assertTrue(is_relevant)
        self.assertGreater(confidence, 0.5)

    def test_relevance_medicine_message(self):
        is_relevant, confidence = classify_relevance_rule_based(
            "Apollo Pharmacy: Your medicines are ready for pickup"
        )
        self.assertTrue(is_relevant)

    def test_irrelevance_otp(self):
        is_relevant, confidence = classify_relevance_rule_based(
            "Your OTP is 839421"
        )
        self.assertFalse(is_relevant)

    def test_irrelevance_spam(self):
        is_relevant, confidence = classify_relevance_rule_based(
            "Congratulations! You won a prize! Click here to claim now!"
        )
        self.assertFalse(is_relevant)

    def test_irrelevance_discount(self):
        is_relevant, confidence = classify_relevance_rule_based(
            "50% off on all items today only!"
        )
        self.assertFalse(is_relevant)

    def test_irrelevance_account_balance(self):
        is_relevant, confidence = classify_relevance_rule_based(
            "Your account balance is Rs. 5430.00"
        )
        self.assertFalse(is_relevant)

    def test_category_bill(self):
        category, confidence = classify_category_rule_based(
            "Electricity bill of Rs. 1240 is due on 15 September"
        )
        self.assertEqual(category, "BILL")
        self.assertGreater(confidence, 0.4)

    def test_category_medicine(self):
        category, confidence = classify_category_rule_based(
            "Apollo Pharmacy: Your medicines are ready for pickup"
        )
        self.assertEqual(category, "MEDICINE")

    def test_category_appointment(self):
        category, confidence = classify_category_rule_based(
            "Doctor appointment at City Hospital tomorrow at 10 AM"
        )
        self.assertEqual(category, "HEALTHCARE_APPOINTMENT")

    def test_category_travel(self):
        category, confidence = classify_category_rule_based(
            "Train leaves from Jhansi station at 6 PM"
        )
        self.assertEqual(category, "TRAVEL")

    def test_category_delivery(self):
        category, confidence = classify_category_rule_based(
            "Your package has been delivered to your doorstep"
        )
        self.assertEqual(category, "DELIVERY")

    def test_classify_message_unified(self):
        result = classify_message(
            "Electricity bill of Rs. 1240 is due on 15 September"
        )
        self.assertTrue(result["is_relevant"])
        self.assertEqual(result["category"], "BILL")
        self.assertIn(result["method"], ("rule_based", "ml"))

    def test_classify_message_irrelevant(self):
        result = classify_message("Your OTP is 839421")
        self.assertFalse(result["is_relevant"])
        self.assertEqual(result["category"], "OTHER")

    def test_fingerprint_deterministic(self):
        fp1 = get_fingerprint("Hello world", "sms")
        fp2 = get_fingerprint("Hello world", "sms")
        self.assertEqual(fp1, fp2)

    def test_fingerprint_different_messages(self):
        fp1 = get_fingerprint("Hello world", "sms")
        fp2 = get_fingerprint("Goodbye world", "sms")
        self.assertNotEqual(fp1, fp2)

    def test_fingerprint_normalizes(self):
        fp1 = get_fingerprint("  Hello   World  ", "SMS")
        fp2 = get_fingerprint("hello world", "sms")
        self.assertEqual(fp1, fp2)


class SmartEventExtractorTests(unittest.TestCase):

    def test_deterministic_extract_bill(self):
        result = _deterministic_extract(
            "Electricity bill of Rs. 1240 is due on 15 September. Pay at billing office."
        )
        self.assertEqual(result["category"], "BILL")
        self.assertEqual(result["amount"], 1240.0)
        self.assertEqual(result["currency"], "INR")
        self.assertEqual(result["action"], "PAY")
        self.assertTrue(result["is_relevant"])
        self.assertGreater(result["confidence"], 0.5)
        self.assertEqual(result["extraction_method"], "deterministic")

    def test_deterministic_extract_medicine(self):
        result = _deterministic_extract(
            "Apollo Pharmacy: Your medicines are ready for pickup."
        )
        self.assertEqual(result["category"], "MEDICINE")
        self.assertEqual(result["action"], "PICKUP")
        self.assertTrue(result["is_relevant"])

    def test_deterministic_extract_appointment(self):
        result = _deterministic_extract(
            "Doctor appointment at City Hospital tomorrow at 10 AM"
        )
        self.assertEqual(result["category"], "HEALTHCARE_APPOINTMENT")
        self.assertIsNotNone(result["due_date"])
        self.assertIsNotNone(result["due_time"])

    def test_deterministic_extract_travel(self):
        result = _deterministic_extract(
            "Train leaves from station at 6 PM"
        )
        self.assertEqual(result["category"], "TRAVEL")
        self.assertEqual(result["due_time"], "18:00")

    def test_deterministic_extract_no_location(self):
        result = _deterministic_extract(
            "Your bill is due tomorrow"
        )
        self.assertIsNone(result["location_name"])

    def test_extract_amount_rupees(self):
        amount, currency = _extract_amount("Rs. 1240")
        self.assertEqual(amount, 1240.0)
        self.assertEqual(currency, "INR")

    def test_extract_amount_dollar(self):
        amount, currency = _extract_amount("$50.00")
        self.assertEqual(amount, 50.0)
        self.assertEqual(currency, "USD")

    def test_extract_amount_none(self):
        amount, currency = _extract_amount("No amount here")
        self.assertIsNone(amount)

    def test_extract_time_am_pm(self):
        time_str = _extract_time("at 10 am")
        self.assertEqual(time_str, "10:00")

        time_str2 = _extract_time("at 6 pm")
        self.assertEqual(time_str2, "18:00")

    def test_extract_time_colon(self):
        time_str = _extract_time("at 14:30")
        self.assertEqual(time_str, "14:30")

    def test_extract_time_none(self):
        time_str = _extract_time("no time here")
        self.assertIsNone(time_str)

    def test_extract_location(self):
        loc = _extract_location("go to the billing office and pay")
        self.assertIsNotNone(loc)
        self.assertIn("billing", loc.lower())

    def test_validate_category_valid(self):
        self.assertEqual(_validate_category("BILL"), "BILL")
        self.assertEqual(_validate_category("bill"), "BILL")
        self.assertEqual(_validate_category("OTHER"), "OTHER")

    def test_validate_category_invalid(self):
        self.assertEqual(_validate_category("random"), "OTHER")

    def test_validate_action_valid(self):
        self.assertEqual(_validate_action("PAY"), "PAY")
        self.assertEqual(_validate_action("pay"), "PAY")

    def test_validate_action_invalid(self):
        self.assertEqual(_validate_action("random"), "OTHER")

    def test_extract_event_returns_none_for_empty(self):
        result = _deterministic_extract("")
        self.assertIsNotNone(result)
        self.assertEqual(result["category"], "OTHER")


if __name__ == "__main__":
    unittest.main()
