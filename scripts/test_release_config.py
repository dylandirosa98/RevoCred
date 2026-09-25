import unittest
from check_release_config import validate


class ReleaseConfigTest(unittest.TestCase):
    def valid(self):
        return dict(REVOCRED_USE_MOCKS="false", REVOCRED_PRODUCTION="true",
                    REVOCRED_API_URL="https://api.example.test", SUPABASE_URL="https://project.example.test",
                    REVOCRED_AUTH_REDIRECT_URL="https://app.example.test/", SUPABASE_ANON_KEY="sb_publishable_example_test_only")

    def test_public_configuration(self):
        validate(self.valid())

    def test_rejects_demo_localhost_and_secret_keys(self):
        for key, value in (("REVOCRED_USE_MOCKS", "true"), ("REVOCRED_API_URL", "http://127.0.0.1:8082"), ("SUPABASE_ANON_KEY", "sb_secret_not_for_browsers")):
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate({**self.valid(), key: value})
