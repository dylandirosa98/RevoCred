import io
import json
import unittest
import urllib.error

import uptime_check


class FakeResponse:
    def __init__(self, status: int, body: bytes):
        self.status = status
        self._body = body

    def read(self) -> bytes:
        return self._body

    def getcode(self) -> int:
        return self.status

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False


class UptimeCheckTests(unittest.TestCase):
    def test_build_checks_default_and_optional_pwa(self):
        base_only = uptime_check.build_checks("https://api.revocred.com/")
        self.assertEqual(
            [c.url for c in base_only],
            [
                "https://api.revocred.com/readyz",
                "https://api.revocred.com/v1/public/chat-disclosure",
                "https://api.revocred.com/privacy",
            ],
        )
        self.assertEqual(base_only[0].expect_json_status, "ready")

        with_pwa = uptime_check.build_checks(
            "https://api.revocred.com",
            "https://app.revocred.com",
        )
        self.assertEqual(len(with_pwa), 4)
        self.assertEqual(with_pwa[-1].url, "https://app.revocred.com")

    def test_run_check_retries_transient_failure_then_passes(self):
        spec = uptime_check.CheckSpec(
            name="API Readiness",
            url="https://api.revocred.com/readyz",
            expect_json=True,
            expect_json_status="ready",
        )
        outcomes = [
            urllib.error.URLError("temporary dns glitch"),
            FakeResponse(200, b'{"status":"ready"}'),
        ]
        sleeps = []

        def fake_open(_req, timeout=10.0):
            nxt = outcomes.pop(0)
            if isinstance(nxt, Exception):
                raise nxt
            return nxt

        result = uptime_check.run_check(
            spec,
            retries=3,
            retry_delay=2.0,
            opener=fake_open,
            sleep_fn=sleeps.append,
        )
        self.assertTrue(result.ok)
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result.attempts, 2)
        self.assertEqual(sleeps, [2.0])

    def test_run_check_fails_when_readyz_status_not_ready(self):
        spec = uptime_check.CheckSpec(
            name="API Readiness",
            url="https://api.revocred.com/readyz",
            expect_json=True,
            expect_json_status="ready",
        )
        sleeps = []

        def fake_open(_req, timeout=10.0):
            return FakeResponse(200, b'{"status":"degraded"}')

        result = uptime_check.run_check(
            spec,
            retries=2,
            retry_delay=1.5,
            opener=fake_open,
            sleep_fn=sleeps.append,
        )
        self.assertFalse(result.ok)
        self.assertEqual(result.attempts, 2)
        self.assertIn("degraded", result.detail)
        self.assertEqual(sleeps, [1.5])

    def test_webhook_payload_shapes_for_discord_slack_and_generic(self):
        results = [
            uptime_check.CheckResult("API Readiness", "https://api.revocred.com/readyz", False, 503, 120, 3, "HTTP 503"),
            uptime_check.CheckResult("Privacy Policy", "https://api.revocred.com/privacy", True, 200, 45, 1, "ok"),
        ]
        discord = uptime_check.build_webhook_payload(
            "https://discord.com/api/webhooks/123/abc",
            results,
            run_url="https://github.com/org/repo/actions/runs/42",
        )
        self.assertIn("content", discord)
        self.assertNotIn("text", discord)
        self.assertIn("API Readiness", discord["content"])
        self.assertIn("runs/42", discord["content"])

        slack = uptime_check.build_webhook_payload(
            "https://hooks.slack.com/services/T00/B00/XXX",
            results,
        )
        self.assertIn("text", slack)
        self.assertNotIn("content", slack)

        generic = uptime_check.build_webhook_payload(
            "https://alerts.example.test/webhook",
            results,
        )
        self.assertIn("text", generic)
        self.assertIn("content", generic)
        self.assertEqual(len(generic["failures"]), 1)

    def test_send_webhook_alert_posts_json(self):
        results = [
            uptime_check.CheckResult("API Readiness", "https://api.revocred.com/readyz", False, 503, 99, 3, "HTTP 503"),
        ]
        captured = {}

        def fake_open(req, timeout=10.0):
            captured["url"] = req.full_url
            captured["method"] = req.get_method()
            captured["body"] = json.loads(req.data.decode("utf-8"))
            return FakeResponse(204, b"")

        uptime_check.send_webhook_alert(
            "https://discord.com/api/webhooks/1/tok",
            results,
            opener=fake_open,
        )
        self.assertEqual(captured["method"], "POST")
        self.assertIn("content", captured["body"])

    def test_render_markdown_summary_marks_skipped_pwa(self):
        results = [
            uptime_check.CheckResult("API Readiness", "https://api.revocred.com/readyz", True, 200, 35, 1, "ok"),
        ]
        md = uptime_check.render_markdown_summary(results, pwa_skipped=True)
        self.assertIn("| API Readiness |", md)
        self.assertIn("PWA_HEALTH_URL", md)


if __name__ == "__main__":
    unittest.main()
