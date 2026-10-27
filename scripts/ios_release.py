#!/usr/bin/env python3
"""Validate public iOS config or create a local IPA. Never uploads or reads server envs."""
import argparse
import json
import ipaddress
from urllib.parse import urlparse
import os
from pathlib import Path
import platform
import plistlib
import re
import shutil
import subprocess

from check_release_config import MOBILE_AUTH_CALLBACK, validate

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "revocred_flutter"
FLUTTER_REVISION = "6b182d2c7585eba26d4edce0f97630effd256c33"
PUBLIC_KEYS = frozenset((
    "REVOCRED_USE_MOCKS", "REVOCRED_PRODUCTION", "REVOCRED_API_URL",
    "SUPABASE_URL", "SUPABASE_ANON_KEY", "REVOCRED_AUTH_REDIRECT_URL",
))


def load_config(path, *, allow_fixture=False):
    # Never source arbitrary shell or copy a backend .env into an application.
    try:
        config = json.loads(Path(path).read_text())
    except (OSError, ValueError):
        raise ValueError("Cannot read public iOS JSON configuration.") from None
    if not isinstance(config, dict) or set(config) != PUBLIC_KEYS:
        raise ValueError("iOS configuration must contain exactly the six public example keys.")
    if not all(isinstance(value, str) for value in config.values()):
        raise ValueError("All iOS configuration values must be strings, including booleans.")
    validate(config)
    if config["REVOCRED_AUTH_REDIRECT_URL"] != MOBILE_AUTH_CALLBACK:
        raise ValueError("iOS requires the exact registered native auth callback.")
    if not allow_fixture:
        reserved = ("localhost", "local", "test", "invalid", "example", "example.com",
                    "example.org", "example.net", "trycloudflare.com", "ngrok.io", "ngrok-free.app")
        for name in ("REVOCRED_API_URL", "SUPABASE_URL"):
            host = (urlparse(config[name]).hostname or "").lower().rstrip(".")
            try:
                # Stable public DNS is required, not even a public numeric address.
                ipaddress.ip_address(host)
                numeric = True
            except ValueError:
                numeric = False
            if numeric or "." not in host or any(host == item or host.endswith("." + item) for item in reserved):
                raise ValueError("Real release requires stable public DNS, not local/tunnel/fixture endpoints.")
        if any(word in config["SUPABASE_ANON_KEY"].lower() for word in ("fixture", "example", "replace")):
            raise ValueError("Real release cannot embed a fixture public key.")
    return config


def validate_project(app=APP):
    with (app / "ios/Runner/Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    schemes = [scheme for item in info.get("CFBundleURLTypes", [])
               for scheme in item.get("CFBundleURLSchemes", [])]
    if "com.revocred.app" not in schemes:
        raise ValueError("The native auth scheme is not registered in Info.plist.")
    if info.get("ITSAppUsesNonExemptEncryption") is not False:
        raise ValueError("Review the iOS encryption declaration before release.")
    with (app / "ios/Runner/PrivacyInfo.xcprivacy").open("rb") as stream:
        privacy = plistlib.load(stream)
    if privacy.get("NSPrivacyTracking") is not False:
        raise ValueError("Review changed tracking behavior before release.")
    project = (app / "ios/Runner.xcodeproj/project.pbxproj").read_text()
    if "PrivacyInfo.xcprivacy in Resources" not in project:
        raise ValueError("Privacy manifest is not registered in Xcode resources.")
    ids = re.findall(r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", project)
    runner_ids = [value.strip('"') for value in ids if not value.endswith(".RunnerTests")]
    if len(runner_ids) != 3 or len(set(runner_ids)) != 1 or not runner_ids[0]:
        raise ValueError("Runner bundle identifiers must agree across all three build configurations.")
    if info.get("CFBundleIdentifier") != "$(PRODUCT_BUNDLE_IDENTIFIER)":
        raise ValueError("Info.plist must inherit the project bundle identifier.")
    targets = re.findall(r"IPHONEOS_DEPLOYMENT_TARGET = ([^;]+);", project)
    if len(targets) != 3 or set(targets) != {"13.0"}:
        raise ValueError("Keep the pinned Flutter iOS minimum consistent at 13.0 in all configurations.")
    if not privacy.get("NSPrivacyAccessedAPITypes"):
        raise ValueError("Review missing required-reason API declarations before release.")
    return runner_ids[0]


def validate_export_options(path):
    try:
        with Path(path).open("rb") as stream:
            options = plistlib.load(stream)
    except (OSError, ValueError, plistlib.InvalidFileException):
        raise ValueError("Cannot read local iOS export-options plist.") from None
    if not isinstance(options, dict):
        raise ValueError("Export options must be a plist dictionary.")
    if options.get("method") != "app-store-connect" or options.get("destination") != "export":
        raise ValueError("Use app-store-connect with destination=export; uploads are separate.")
    if not re.fullmatch(r"[A-Z0-9]{10}", str(options.get("teamID", ""))):
        raise ValueError("Set your real 10-character Apple team ID in export options.")


def require_apple_toolchain():
    if platform.system() != "Darwin":
        raise ValueError("Signed iOS builds require macOS with Xcode 26+ and iOS 26+ SDK.")
    try:
        version = subprocess.check_output(["xcodebuild", "-version"], text=True)
        sdk = subprocess.check_output(
            ["xcrun", "--sdk", "iphoneos", "--show-sdk-version"], text=True)
    except (OSError, subprocess.CalledProcessError):
        raise ValueError("Select a full Xcode installation and finish its first-launch setup.") from None
    match = re.search(r"Xcode (\d+)", version)
    if match is None or int(match[1]) < 26 or int(sdk.strip().split(".")[0]) < 26:
        raise ValueError("App Store Connect uploads require Xcode 26+ and iOS 26+ SDK.")


def flutter_executable():
    flutter = os.environ.get("FLUTTER") or shutil.which("flutter")
    if not flutter:
        flutter = str(Path.home() / ".local/share/flutter/bin/flutter")
    if not Path(flutter).is_file():
        # FLUTTER may be a command on PATH instead of an absolute filename.
        flutter = shutil.which(flutter)
    if not flutter:
        raise ValueError("Flutter is missing; set FLUTTER or add the pinned SDK to PATH.")
    return flutter


def require_flutter_revision(flutter):
    try:
        version = json.loads(subprocess.check_output(
            [flutter, "--version", "--machine"], text=True))
    except (OSError, ValueError, subprocess.CalledProcessError):
        raise ValueError("Cannot inspect the Flutter SDK version.") from None
    if not isinstance(version, dict) or version.get("frameworkRevision") != FLUTTER_REVISION:
        raise ValueError("Use the exact Flutter SDK revision pinned in the iOS CI workflow.")


def build_command(flutter, config, build_number, export_options):
    if not re.fullmatch(r"[1-9][0-9]*", build_number):
        raise ValueError("Provide a positive integer --build-number, newer than previous uploads.")
    return [flutter, "build", "ipa", "--release",
            "--build-number=" + build_number,
            "--dart-define-from-file=" + str(Path(config).resolve()),
            "--export-options-plist=" + str(Path(export_options).resolve())]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default=str(ROOT / ".env.ios.json"))
    parser.add_argument("--check", action="store_true", help="Offline config/static checks only; works on Linux")
    parser.add_argument("--build-number", default="")
    parser.add_argument("--export-options", default=str(ROOT / ".local/ios/ExportOptions.plist"))
    args = parser.parse_args(argv)
    try:
        load_config(args.config)
        validate_project()
        if args.check:
            print("Public iOS config/static checks passed. Signing, consent, hosted services and review remain separate gates.")
            return 0
        validate_export_options(args.export_options)
        command = build_command(flutter_executable(), args.config, args.build_number, args.export_options)
        require_apple_toolchain()
        require_flutter_revision(command[0])
        subprocess.run([command[0], "pub", "get", "--enforce-lockfile"], cwd=APP, check=True)
        subprocess.run(command, cwd=APP, check=True)
        print("Local build completed; inspect build/ios/archive and build/ios/ipa under revocred_flutter.")
        print("Validate the archive and device/privacy acceptance gates before uploading. Nothing was uploaded.")
        return 0
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        # Do not echo config values, tokens, JSON parser excerpts or build commands.
        if isinstance(error, subprocess.CalledProcessError):
            print("iOS build command failed; inspect the tool output above.")
        elif isinstance(error, OSError):
            print("Cannot read required iOS project files or execute build tools.")
        else:
            print(str(error))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
