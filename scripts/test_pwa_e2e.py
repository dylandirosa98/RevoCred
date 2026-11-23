"""Unit tests for browser_smoke and pwa_e2e helpers and safety guards."""
import importlib
import sys
import types
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parent
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))


def _import_with_playwright_stub(module_name: str):
    if 'playwright' in sys.modules:
        return importlib.import_module(module_name)
    pw = types.ModuleType('playwright')
    sync_api = types.ModuleType('playwright.sync_api')
    sync_api.sync_playwright = object()
    sync_api.expect = object()
    pw.sync_api = sync_api
    with mock.patch.dict(sys.modules, {'playwright': pw, 'playwright.sync_api': sync_api}):
        return importlib.import_module(module_name)


browser_smoke = _import_with_playwright_stub('browser_smoke')
pwa_e2e = _import_with_playwright_stub('pwa_e2e')


class BrowserSmokeHelpersTest(unittest.TestCase):
    def test_loopback_and_share_guard_rejects_production(self):
        browser_smoke.assert_loopback_or_share('http://127.0.0.1:8083')
        browser_smoke.assert_loopback_or_share('http://localhost:54321')
        browser_smoke.assert_loopback_or_share(
            'https://preview-abc.trycloudflare.com', allow_share_tunnel=True
        )
        with self.assertRaises(SystemExit):
            browser_smoke.assert_loopback_or_share('https://api.revocred.com')
        with self.assertRaises(SystemExit):
            browser_smoke.assert_loopback_or_share(
                'https://revocred-pwa.vercel.app', allow_share_tunnel=True
            )
        with self.assertRaises(SystemExit):
            browser_smoke.assert_loopback_or_share(
                'http://preview-abc.trycloudflare.com', allow_share_tunnel=True
            )

    def test_extract_verify_link_validates_origin_and_auth_host(self):
        msg = {
            'HTML': (
                '<a href="http://127.0.0.1:54321/auth/v1/verify?'
                'token=abc&amp;type=recovery&amp;redirect_to=http%3A%2F%2F127.0.0.1%3A8083%2F%3Frecovery%3Dtrue">'
                'Reset</a>'
            )
        }
        link = browser_smoke.extract_verify_link(
            msg,
            expected_auth_host='127.0.0.1',
            expected_web_origin='http://127.0.0.1:8083',
        )
        self.assertIn('/auth/v1/verify', link)
        self.assertIn('recovery%3Dtrue', link)

        with self.assertRaisesRegex(AssertionError, 'origin mismatch'):
            browser_smoke.extract_verify_link(
                msg,
                expected_auth_host='127.0.0.1',
                expected_web_origin='https://other.trycloudflare.com',
            )

        external_msg = {
            'HTML': '<a href="https://evil.example/auth/v1/verify?token=x">Reset</a>'
        }
        with self.assertRaisesRegex(AssertionError, 'Unexpected external'):
            browser_smoke.extract_verify_link(
                external_msg, expected_auth_host='127.0.0.1'
            )

    def test_resolve_chromium_prefers_valid_override(self):
        with mock.patch.dict('os.environ', {'CHROMIUM_PATH': str(Path(__file__))}):
            self.assertEqual(
                browser_smoke.resolve_chromium_executable(), str(Path(__file__))
            )


class PwaE2eHarnessTest(unittest.TestCase):
    def test_local_harness_wallet_score_excludes_skipped_terms(self):
        state = pwa_e2e.LocalHarnessState('http://127.0.0.1:5000', 'http://127.0.0.1:5001')
        sapphire = {'id': 'w1', 'status': 'active', 'card': state.catalog[0]}
        citi_scored = {
            'id': 'w2',
            'status': 'active',
            'card': {
                'id': 'c2',
                'name': 'Citi Custom Cash',
                'reward_rates': {'groceries': 5, 'other': 1},
                'terms_unknown': False,
                'transferable_points': False,
            },
        }
        skipped = {
            'id': 'w3',
            'status': 'active',
            'card': {
                'id': 'c3',
                'name': 'Discover it Chrome',
                'reward_rates': {'groceries': 10, 'other': 10},
                'terms_unknown': True,
                'transferable_points': False,
            },
        }
        s1 = state._wallet_score([sapphire])
        s2 = state._wallet_score([sapphire, citi_scored])
        s3 = state._wallet_score([sapphire, citi_scored, skipped])
        self.assertGreater(s2, s1)
        self.assertEqual(s3, s2)

    def test_make_jwt_has_three_parts(self):
        token = pwa_e2e.make_jwt('user-1', 'qa@example.test')
        self.assertEqual(len(token.split('.')), 3)


if __name__ == '__main__':
    unittest.main()
