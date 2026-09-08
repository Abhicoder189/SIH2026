import unittest

from app.adaptation import calculate_performance_score, recommend_difficulty
from app.analytics import analyze_patient_performance
from app.schemas import UserRegister
from app.task_context_engine import build_task_context, _derive_journey_state, _get_step_info
from app.context_response_generator import generate_response
from app.instruction_parser import _fallback_parse


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


if __name__ == "__main__":
    unittest.main()
