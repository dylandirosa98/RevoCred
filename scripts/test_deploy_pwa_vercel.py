import json
from pathlib import Path
import tempfile
import unittest

import deploy_pwa_vercel as dpv

ROOT = Path(__file__).resolve().parents[1]


class DeployPwaVercelTests(unittest.TestCase):
    def base_config(self, **overrides):
        config = {
            "REVOCRED_USE_MOCKS": "false",
            "REVOCRED_PRODUCTION": "true",
            "REVOCRED_API_URL": "https://api.revocred.com",
            "SUPABASE_URL": "https://project.supabase.co",
            "SUPABASE_ANON_KEY": "sb_publishable_example_public_key_123",
            "REVOCRED_AUTH_REDIRECT_URL": "https://app.revocred.com/",
            "REVOCRED_LEGAL_ENTITY": "RevoCred Example LLC",
            "REVOCRED_LEGAL_JURISDICTION": "Delaware, USA",
            "REVOCRED_LEGAL_EFFECTIVE_DATE": "2026-11-23",
            "REVOCRED_SUPPORT_EMAIL": "support@revocred.com",
            "REVOCRED_PRIVACY_URL": "https://api.revocred.com/privacy",
            "REVOCRED_TERMS_URL": "https://api.revocred.com/terms",
            "REVOCRED_SUPPORT_URL": "https://api.revocred.com/support",
        }
        config.update(overrides)
        return config

    def test_validates_complete_production_pwa_config(self):
        dpv.validate_pwa_config(self.base_config())

    def test_rejects_native_callback_and_mocks_and_secret_keys(self):
        for overrides in (
            {"REVOCRED_USE_MOCKS": "true"},
            {"REVOCRED_AUTH_REDIRECT_URL": "com.revocred.app://auth-callback/"},
            {"SUPABASE_ANON_KEY": "sb_secret_never_ship_this"},
            {"REVOCRED_LEGAL_ENTITY": "{{LEGAL_ENTITY}}"},
            {"REVOCRED_PRODUCTION": "false", "REVOCRED_API_URL": "http://127.0.0.1:8082"},
        ):
            with self.subTest(overrides=overrides), self.assertRaises(ValueError):
                dpv.validate_pwa_config(self.base_config(**overrides))

    def test_allows_prelaunch_real_mode_without_legal_entity(self):
        prelaunch = self.base_config(
            REVOCRED_PRODUCTION="false",
            REVOCRED_LEGAL_ENTITY="",
            REVOCRED_LEGAL_JURISDICTION="",
            REVOCRED_LEGAL_EFFECTIVE_DATE="",
            REVOCRED_AUTH_REDIRECT_URL="https://revocred-pwa.vercel.app/",
        )
        dpv.validate_pwa_config(prelaunch)

    def test_parse_env_file_ignores_unknown_backend_secrets(self):
        with tempfile.TemporaryDirectory() as directory:
            env_path = Path(directory) / ".env.test"
            env_path.write_text(
                "\n".join(
                    [
                        "# comment",
                        'REVOCRED_API_URL="https://api.revocred.com"',
                        "SUPABASE_URL=https://project.supabase.co",
                        "SUPABASE_ANON_KEY=sb_publishable_example_public_key_123",
                        "DATABASE_URL=postgres://secret",
                        "AI_API_KEY=sk-secret",
                    ]
                ),
                encoding="utf-8",
            )
            parsed = dpv.parse_env_file(env_path)
            self.assertEqual(parsed["REVOCRED_API_URL"], "https://api.revocred.com")
            self.assertNotIn("DATABASE_URL", parsed)
            self.assertNotIn("AI_API_KEY", parsed)

    def test_resolve_and_build_command_wire_all_legal_defines(self):
        config = self.base_config()
        cmd = dpv.flutter_build_command("/usr/bin/flutter", config, Path("/tmp/web-out"))
        self.assertIn("--release", cmd)
        self.assertIn("--no-web-resources-cdn", cmd)
        for key in dpv.BUILD_DEFINE_KEYS:
            self.assertIn(f"--dart-define={key}={config[key]}", cmd)

    def test_stage_vercel_config_and_deploy_command(self):
        with tempfile.TemporaryDirectory() as directory:
            out = Path(directory)
            staged = dpv.stage_vercel_config(out)
            self.assertTrue(staged.is_file())
            parsed = json.loads(staged.read_text(encoding="utf-8"))
            self.assertIn("headers", parsed)
            self.assertIn("rewrites", parsed)

        prod_cmd = dpv.vercel_deploy_command(
            "vercel",
            Path("/tmp/web"),
            prod=True,
            project="revocred-pwa",
            scope="team-123",
            token="tok",
        )
        self.assertIn("--prod", prod_cmd)
        self.assertIn("--project", prod_cmd)
        self.assertIn("revocred-pwa", prod_cmd)
        self.assertIn("--scope", prod_cmd)
        self.assertIn("--token", prod_cmd)

        preview_cmd = dpv.vercel_deploy_command(
            "vercel",
            Path("/tmp/web"),
            prod=False,
            project="revocred-pwa",
            scope="team-123",
        )
        self.assertNotIn("--prod", preview_cmd)
        self.assertNotIn("--token", preview_cmd)

    def test_pwa_web_assets_and_vercel_json_meet_production_standards(self):
        vercel_cfg = json.loads((ROOT / "revocred_flutter/vercel.json").read_text(encoding="utf-8"))
        all_headers = {
            h["key"]: h["value"]
            for rule in vercel_cfg["headers"]
            for h in rule["headers"]
        }
        for key in (
            "X-Content-Type-Options",
            "Referrer-Policy",
            "X-Frame-Options",
            "Permissions-Policy",
            "Content-Security-Policy",
            "Cache-Control",
        ):
            self.assertIn(key, all_headers)

        no_cache_sources = [
            rule["source"]
            for rule in vercel_cfg["headers"]
            if any(
                h["key"] == "Cache-Control" and "no-store" in h["value"]
                for h in rule["headers"]
            )
        ]
        self.assertTrue(
            any("flutter_bootstrap" in src and "manifest" in src and "pwa_sw" in src for src in no_cache_sources)
        )

        manifest = json.loads((ROOT / "revocred_flutter/web/manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["name"], "RevoCred")
        self.assertEqual(manifest["display"], "standalone")
        self.assertEqual(manifest["start_url"], "/")

        index_html = (ROOT / "revocred_flutter/web/index.html").read_text(encoding="utf-8")
        bootstrap_js = (ROOT / "revocred_flutter/web/flutter_bootstrap.js").read_text(encoding="utf-8")
        self.assertIn("viewport-fit=cover", index_html)
        self.assertIn("apple-mobile-web-app-capable", index_html)
        self.assertIn("mobile-web-app-capable", index_html)
        self.assertIn("og:title", index_html)
        self.assertIn("twitter:card", index_html)
        self.assertIn("prefers-color-scheme: dark", index_html)
        self.assertIn('src="flutter_bootstrap.js"', index_html)
        self.assertNotIn("Reload preview", index_html)
        self.assertNotIn("The preview could not start", bootstrap_js)
        self.assertIn("pwa_sw.js", bootstrap_js)
        self.assertTrue((ROOT / "revocred_flutter/web/pwa_sw.js").is_file())


if __name__ == "__main__":
    unittest.main()
