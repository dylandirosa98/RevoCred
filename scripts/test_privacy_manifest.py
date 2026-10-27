"""Source manifest checks; not signed SDK aggregation or App Store approval."""
import pathlib
import plistlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class PrivacyManifestTest(unittest.TestCase):
    def test_financial_inputs_disclose_recommendation_personalization(self):
        with (ROOT / 'revocred_flutter/ios/Runner/PrivacyInfo.xcprivacy').open('rb') as handle:
            manifest = plistlib.load(handle)
        rows = {row['NSPrivacyCollectedDataType']: row for row in manifest['NSPrivacyCollectedDataTypes']}
        for kind in ('CreditInfo', 'OtherFinancialInfo', 'OtherUserContent'):
            with self.subTest(kind=kind):
                self.assertIn('NSPrivacyCollectedDataTypePurposeProductPersonalization',
                              rows['NSPrivacyCollectedDataType' + kind]['NSPrivacyCollectedDataTypePurposes'])
        self.assertFalse(manifest['NSPrivacyTracking'])
        self.assertEqual(manifest['NSPrivacyTrackingDomains'], [])


if __name__ == '__main__':
    unittest.main()
