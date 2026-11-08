import json
import subprocess
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import ios_ci
import ios_release


class IOSCITest(unittest.TestCase):
    def test_bootstraps_flutter_before_machine_version_inspection(self):
        order = []
        def run(command, *args, **kwargs):
            order.append(command)
        def inspect(flutter):
            self.assertIn([flutter, '--version'], order)
            raise ValueError('stop after inspected bootstrap')
        with patch.object(ios_ci, 'require_apple_toolchain'), \
                patch.object(ios_ci, 'flutter_executable', return_value='flutter'), \
                patch.object(ios_ci, 'run', side_effect=run), \
                patch.object(ios_ci, 'require_flutter_revision', side_effect=inspect):
            with self.assertRaises(ValueError):
                ios_ci.native_build(Path('.'), Path('fixture'), {})

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

    def test_launched_pid_is_read_from_simctl_output(self):
        bundle = 'com.revocred.revocredFlutter'
        self.assertEqual(ios_ci.launched_pid(f'{bundle}: 27498\n', bundle), 27498)
        self.assertIsNone(ios_ci.launched_pid('An error was encountered', bundle))

    def test_alive_check_uses_host_pid_before_launchctl(self):
        sim = ['xcrun', 'simctl']
        calls = []

        def fake_run(command, **_):
            calls.append(command)
            if command[0] == 'ps':
                return subprocess.CompletedProcess(command, 0, stdout='27498\n', stderr='')
            raise AssertionError('launchctl should not run when the pid is alive')

        with tempfile.TemporaryDirectory() as directory, \
                patch.object(ios_ci.subprocess, 'run', side_effect=fake_run):
            log = Path(directory) / 'alive.log'
            self.assertTrue(ios_ci.app_alive(sim, 'udid', 'bundle', 27498, log))
            self.assertIn('exit 0', log.read_text())
        self.assertEqual(calls, [['ps', '-p', '27498', '-o', 'pid=']])

    def test_alive_check_reports_exited_app_and_launchctl_failure(self):
        def fake_run(command, **_):
            if command[0] == 'ps':
                return subprocess.CompletedProcess(command, 1, stdout='', stderr='')
            return subprocess.CompletedProcess(command, 1, stdout='', stderr='boom')

        with tempfile.TemporaryDirectory() as directory, \
                patch.object(ios_ci.subprocess, 'run', side_effect=fake_run):
            log = Path(directory) / 'alive.log'
            self.assertFalse(ios_ci.app_alive(['xcrun', 'simctl'], 'udid', 'bundle', 27498, log))
            self.assertIn('launchctl list: exit 1', log.read_text())

    def test_slow_cleanup_is_recorded_not_fatal(self):
        def slow(command, **_):
            raise subprocess.TimeoutExpired(command, 60)

        with tempfile.TemporaryDirectory() as directory, \
                patch.object(ios_ci.subprocess, 'run', side_effect=slow):
            ios_ci.cleanup(['xcrun', 'simctl'], 'udid', 'iphone', Path(directory))
            notes = (Path(directory) / 'iphone-cleanup.log').read_text()
        self.assertIn('runtime log incomplete: TimeoutExpired', notes)
        self.assertIn('shutdown did not finish: TimeoutExpired', notes)

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
