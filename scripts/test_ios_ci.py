import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import ios_ci
import ios_release


class IOSCITest(unittest.TestCase):
    def test_fixture_is_explicit_and_rejected_for_distribution(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'compile-fixture.json'
            ios_ci.write_fixture(path)
            config = ios_release.load_config(path, allow_fixture=True)
            self.assertEqual(config['REVOCRED_USE_MOCKS'], 'false')
            self.assertTrue(config['REVOCRED_API_URL'].endswith('.test'))
            with self.assertRaises(ValueError):
                ios_release.load_config(path)

    def test_simulators_require_ios26_and_both_device_families(self):
        devices = {'devices': {
            'com.apple.CoreSimulator.SimRuntime.iOS-18-5': [
                {'name': 'iPhone old', 'udid': 'old', 'isAvailable': True}],
            'com.apple.CoreSimulator.SimRuntime.iOS-26-0': [
                {'name': 'iPhone 17', 'udid': 'phone', 'isAvailable': True},
                {'name': 'iPad Pro', 'udid': 'pad', 'isAvailable': True}]}}
        self.assertEqual([x['udid'] for x in ios_ci.choose_simulators(devices)], ['phone', 'pad'])
        devices['devices'].pop('com.apple.CoreSimulator.SimRuntime.iOS-26-0')
        with self.assertRaises(ValueError):
            ios_ci.choose_simulators(devices)

    def test_native_failure_is_recorded_and_returns_nonzero(self):
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(ios_ci, 'native_build', side_effect=ValueError('native compile failed')):
            self.assertEqual(ios_ci.main(['--output', directory]), 1)
            result = json.loads((Path(directory) / 'build-result.json').read_text())
            self.assertEqual(result['status'], 'failed')
            self.assertFalse(result['testflight_ready'])
            self.assertEqual(result['kind'], 'compile-fixture-only')

    def test_static_only_never_claims_native_success(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(ios_ci, 'native_build') as native:
            self.assertEqual(ios_ci.main(['--output', directory, '--preflight-only']), 0)
            result = json.loads((Path(directory) / 'build-result.json').read_text())
            self.assertEqual(result['status'], 'static-passed-native-unverified')
            self.assertFalse(result['testflight_ready'])
            native.assert_not_called()

    def test_signed_command_cannot_use_ci_fixture_bypass(self):
        workflow = (ios_release.ROOT / '.github/workflows/ios.yml').read_text()
        self.assertIn("'release/**'", workflow)
        self.assertNotIn('secrets.', workflow)
        self.assertIn('cancel-in-progress: true', workflow)
        self.assertIn('retention-days: 7', workflow)
