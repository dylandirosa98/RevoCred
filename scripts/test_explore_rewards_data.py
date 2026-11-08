"""The app bundles the Explore Rewards examples as an offline fallback; they must
match the API's copy exactly so members see the same numbers either way."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
API_COPY = ROOT / "revocred-api/internal/explore/rewards.json"
APP_COPY = ROOT / "revocred_flutter/assets/data/explore_rewards.json"


class ExploreRewardsDataTest(unittest.TestCase):
    def test_app_copy_matches_api_copy(self):
        self.assertEqual(
            API_COPY.read_bytes(),
            APP_COPY.read_bytes(),
            "Copy revocred-api/internal/explore/rewards.json to "
            "revocred_flutter/assets/data/explore_rewards.json",
        )


if __name__ == "__main__":
    unittest.main()
