import unittest
from pathlib import Path
from check_release_config import validate


class ReleaseConfigTest(unittest.TestCase):
    def test_production_compose_has_no_personal_testing_key_fallback(self):
        compose = (Path(__file__).resolve().parents[1] / "compose.production.yaml").read_text()
        for name in ("AI_API_KEY", "AI_MODEL", "AI_BASE_URL"):
            setting = next(line.strip() for line in compose.splitlines() if line.strip().startswith(name + ":"))
            self.assertEqual(setting, name + ": ${" + name + ":-}")

    def valid(self):
        return dict(REVOCRED_USE_MOCKS="false", REVOCRED_PRODUCTION="true",
                    REVOCRED_API_URL="https://api.example.test", SUPABASE_URL="https://project.example.test",
                    REVOCRED_AUTH_REDIRECT_URL="https://app.example.test/", SUPABASE_ANON_KEY="sb_publishable_example_test_only",
                    REVOCRED_LEGAL_ENTITY="RevoCred Example LLC", REVOCRED_SUPPORT_EMAIL="support@example.test",
                    REVOCRED_LEGAL_JURISDICTION="New Jersey, USA", REVOCRED_LEGAL_EFFECTIVE_DATE="2026-11-06",
                    REVOCRED_PRIVACY_URL="https://app.example.test/privacy", REVOCRED_TERMS_URL="https://app.example.test/terms")

    def test_public_configuration(self):
        validate(self.valid())

    def test_mobile_auth_callback(self):
        validate({**self.valid(), "REVOCRED_AUTH_REDIRECT_URL": "com.revocred.app://auth-callback/"})
        for value in ("com.evil.app://auth-callback/", "com.revocred.app://other/", "http://app.example.test/"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                validate({**self.valid(), "REVOCRED_AUTH_REDIRECT_URL": value})

    def test_rejects_unfilled_legal_template(self):
        for key, value in (("REVOCRED_LEGAL_ENTITY", "{{LEGAL_ENTITY}}"), ("REVOCRED_SUPPORT_EMAIL", ""),
                           ("REVOCRED_PRIVACY_URL", "https://example.com/privacy"), ("REVOCRED_TERMS_URL", "http://app.example.test/terms")):
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate({**self.valid(), key: value})

    def test_rejects_demo_localhost_and_secret_keys(self):
        for key, value in (("REVOCRED_USE_MOCKS", "true"), ("REVOCRED_API_URL", "http://127.0.0.1:8082"), ("SUPABASE_ANON_KEY", "sb_secret_not_for_browsers")):
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate({**self.valid(), key: value})
