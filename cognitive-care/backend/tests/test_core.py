import unittest

from app.adaptation import calculate_performance_score, recommend_difficulty
from app.analytics import analyze_patient_performance
from app.schemas import UserRegister


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


if __name__ == "__main__":
    unittest.main()
