import contextlib
import io
import json
from pathlib import Path
import plistlib
import shutil
import tempfile
import unittest
from unittest.mock import patch

import ios_release


class IOSReleaseTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.config = Path(self.temp.name) / "public.json"
        self.options = Path(self.temp.name) / "ExportOptions.plist"
        self.values = dict(
            REVOCRED_USE_MOCKS="false", REVOCRED_PRODUCTION="true",
            REVOCRED_API_URL="https://api.example.test",
            SUPABASE_URL="https://project.example.test",
            SUPABASE_ANON_KEY="sb_publishable_example_test_only",
            REVOCRED_AUTH_REDIRECT_URL=ios_release.MOBILE_AUTH_CALLBACK,
        )
        self.config.write_text(json.dumps(self.values))
        self.options.write_bytes(plistlib.dumps(dict(
            method="app-store-connect", destination="export", teamID="AB12345678")))

    def test_public_config_and_native_project(self):
        self.assertEqual(ios_release.load_config(self.config, allow_fixture=True), self.values)
        ios_release.validate_project()
        ios_release.validate_export_options(self.options)

    def test_fixture_is_never_a_real_release_configuration(self):
        with self.assertRaisesRegex(ValueError, "fixture|public|production"):
            ios_release.load_config(self.config)

    def test_rejects_private_reserved_and_tunnel_release_hosts(self):
        for host in ("127.1.2.3", "192.168.1.1", "api.local", "api.test",
                     "api.example.com", "preview.trycloudflare.com", "abc.ngrok-free.app"):
            self.config.write_text(json.dumps({**self.values,
                "REVOCRED_API_URL": "https://" + host,
                "SUPABASE_URL": "https://project.supabase.co",
                "SUPABASE_ANON_KEY": "sb_publishable_not_a_verified_key"}))
            with self.subTest(host=host), self.assertRaises(ValueError):
                ios_release.load_config(self.config)

    def test_native_project_rejects_missing_or_drifting_release_metadata(self):
        for old, new in (("IPHONEOS_DEPLOYMENT_TARGET = 13.0;", "IPHONEOS_DEPLOYMENT_TARGET = 12.0;"),
                         ("PRODUCT_BUNDLE_IDENTIFIER = com.revocred.revocredFlutter;", "PRODUCT_BUNDLE_IDENTIFIER = wrong.bundle;"),
                         ("PrivacyInfo.xcprivacy in Resources", "Missing.xcprivacy in Resources")):
            with self.subTest(old=old), tempfile.TemporaryDirectory() as directory:
                app = Path(directory)
                for relative in ('Runner/Info.plist', 'Runner/PrivacyInfo.xcprivacy', 'Runner.xcodeproj/project.pbxproj'):
                    target = app / 'ios' / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(ios_release.APP / 'ios' / relative, target)
                project = app / 'ios/Runner.xcodeproj/project.pbxproj'
                project.write_text(project.read_text().replace(old, new, 2 if old.startswith('Privacy') else 1))
                with self.assertRaises(ValueError):
                    ios_release.validate_project(app)

    def test_unknown_secret_keys_never_enter_client(self):
        self.config.write_text(json.dumps({**self.values, "DATABASE_URL": "secret"}))
        with self.assertRaises(ValueError):
            ios_release.load_config(self.config)

    def test_rejects_bad_config_and_web_callback(self):
        for key, value in (("REVOCRED_USE_MOCKS", "true"),
                           ("REVOCRED_PRODUCTION", "false"),
                           ("REVOCRED_PRODUCTION", True),
                           ("REVOCRED_API_URL", "http://localhost:8082"),
                           ("SUPABASE_ANON_KEY", "sb_secret_private"),
                           ("REVOCRED_AUTH_REDIRECT_URL", "https://app.example.test")):
            with self.subTest(key=key, value=value):
                self.config.write_text(json.dumps({**self.values, key: value}))
                with self.assertRaises(ValueError):
                    ios_release.load_config(self.config)

    def test_invalid_json_does_not_echo_private_values(self):
        self.config.write_text('{"private-key-must-not-leak"')
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            self.assertEqual(ios_release.main(["--config", str(self.config), "--check"]), 1)
        self.assertNotIn("private-key-must-not-leak", output.getvalue())

    def test_config_is_exactly_public_string_keys(self):
        for value in ([], {**self.values, "SUPABASE_ANON_KEY": None},
                      {key: item for key, item in self.values.items() if key != "SUPABASE_URL"}):
            self.config.write_text(json.dumps(value))
            with self.assertRaises(ValueError):
                ios_release.load_config(self.config)

    def test_check_is_offline_and_never_builds(self):
        self.config.write_text(json.dumps({**self.values,
            "REVOCRED_API_URL": "https://api.revocred.com",
            "SUPABASE_URL": "https://project.supabase.co",
            "SUPABASE_ANON_KEY": "sb_publishable_unit_test_only_123"}))
        with patch.object(ios_release.subprocess, "run") as run, \
                patch.object(ios_release.subprocess, "check_output") as output, \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(ios_release.main(["--config", str(self.config), "--check"]), 0)
        run.assert_not_called()
        output.assert_not_called()

    def test_release_command_contains_no_keys_or_inline_defines(self):
        command = ios_release.build_command("flutter", self.config, "42", self.options)
        self.assertIn("--release", command)
        self.assertIn("--build-number=42", command)
        self.assertIn("ipa", command)
        self.assertFalse(any("sb_publishable" in item for item in command))
        self.assertFalse(any(item.startswith("--dart-define=") for item in command))

    def test_build_numbers_are_explicit_positive_integers(self):
        for value in ("", "0", "-1", "1.0", "abc"):
            with self.assertRaises(ValueError):
                ios_release.build_command("flutter", self.config, value, self.options)

    def test_export_cannot_implicitly_upload(self):
        for change in (dict(destination="upload"), dict(method="development"), dict(teamID="REPLACE")):
            self.options.write_bytes(plistlib.dumps(dict(
                method="app-store-connect", destination="export", teamID="AB12345678") | change))
            with self.assertRaises(ValueError):
                ios_release.validate_export_options(self.options)

    def test_linux_cannot_claim_signed_build(self):
        with patch.object(ios_release.platform, "system", return_value="Linux"):
            with self.assertRaisesRegex(ValueError, "macOS"):
                ios_release.require_apple_toolchain()

    def test_xcode_and_sdk_minimums(self):
        for xcode, sdk, allowed in (("Xcode 26.0", "26.0", True),
                                     ("Xcode 16.4", "18.5", False),
                                     ("Xcode 26.0", "18.5", False)):
            with self.subTest(xcode=xcode, sdk=sdk), \
                    patch.object(ios_release.platform, "system", return_value="Darwin"), \
                    patch.object(ios_release.subprocess, "check_output", side_effect=[xcode, sdk]):
                if allowed:
                    ios_release.require_apple_toolchain()
                else:
                    with self.assertRaises(ValueError):
                        ios_release.require_apple_toolchain()

    def test_flutter_revision_matches_ci_and_cannot_drift(self):
        workflow = (ios_release.ROOT / ".github/workflows/ios.yml").read_text()
        self.assertIn("ref: " + ios_release.FLUTTER_REVISION, workflow)
        for revision in (ios_release.FLUTTER_REVISION, "different-sdk"):
            with patch.object(ios_release.subprocess, "check_output", return_value=json.dumps(
                    dict(frameworkRevision=revision))):
                if revision == ios_release.FLUTTER_REVISION:
                    ios_release.require_flutter_revision("flutter")
                else:
                    with self.assertRaises(ValueError):
                        ios_release.require_flutter_revision("flutter")
