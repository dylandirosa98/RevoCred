#!/usr/bin/env python3
"""Build and deploy the RevoCred Flutter Web PWA to Vercel.

Reads only public client defines (never backend secrets) from an optional
KEY=VALUE or JSON file plus environment/CLI overrides, validates the build
configuration with both Python and `dart run tool/validate_build.dart`, compiles
`flutter build web --release --no-web-resources-cdn`, copies
`revocred_flutter/vercel.json` into the output directory, and deploys via the
Vercel CLI.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from urllib.parse import urlparse

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_release_config import (  # noqa: E402
    DEFAULT_SUPPORT_URL,
    validate as validate_production_release,
    validate_public_key,
)

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "revocred_flutter"
VERCEL_CONFIG = APP / "vercel.json"
DEFAULT_VERCEL_PROJECT = "revocred-pwa"
DEFAULT_VERCEL_SCOPE = "dylans-projects-62ab0a08"

DEFAULT_PRIVACY_URL = "https://api.revocred.com/privacy"
DEFAULT_TERMS_URL = "https://api.revocred.com/terms"
DEFAULT_SUPPORT_EMAIL = "support@revocred.com"

BUILD_DEFINE_KEYS = (
    "REVOCRED_USE_MOCKS",
    "REVOCRED_PRODUCTION",
    "REVOCRED_API_URL",
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
    "REVOCRED_AUTH_REDIRECT_URL",
    "REVOCRED_LEGAL_ENTITY",
    "REVOCRED_LEGAL_JURISDICTION",
    "REVOCRED_LEGAL_EFFECTIVE_DATE",
    "REVOCRED_SUPPORT_EMAIL",
    "REVOCRED_PRIVACY_URL",
    "REVOCRED_TERMS_URL",
    "REVOCRED_SUPPORT_URL",
)


def parse_env_file(path: Path) -> dict[str, str]:
    """Parse a KEY=VALUE or JSON file containing public build defines."""
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError:
        raise ValueError(f"Cannot read build config file: {path.name}") from None
    stripped = raw.lstrip()
    if stripped.startswith("{"):
        try:
            parsed = json.loads(raw)
        except ValueError:
            raise ValueError(f"Invalid JSON build config: {path.name}") from None
        if not isinstance(parsed, dict) or not all(
            isinstance(k, str) and isinstance(v, str) for k, v in parsed.items()
        ):
            raise ValueError("JSON build config must map string keys to string values.")
        return {k: v for k, v in parsed.items() if k in BUILD_DEFINE_KEYS}

    values: dict[str, str] = {}
    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, sep, value = line.partition("=")
        if not sep:
            continue
        key = key.strip()
        if key not in BUILD_DEFINE_KEYS:
            continue
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
            value = value[1:-1]
        values[key] = value
    return values


def resolve_build_config(
    *,
    env: dict[str, str],
    env_file: Path | None = None,
    auth_redirect_url: str | None = None,
    production_override: bool | None = None,
) -> dict[str, str]:
    """Merge defaults, optional env file, process environment, and CLI flags."""
    config: dict[str, str] = {
        "REVOCRED_USE_MOCKS": "false",
        "REVOCRED_PRODUCTION": "false",
        "REVOCRED_API_URL": "",
        "SUPABASE_URL": "",
        "SUPABASE_ANON_KEY": "",
        "REVOCRED_AUTH_REDIRECT_URL": "",
        "REVOCRED_LEGAL_ENTITY": "",
        "REVOCRED_LEGAL_JURISDICTION": "",
        "REVOCRED_LEGAL_EFFECTIVE_DATE": "",
        "REVOCRED_SUPPORT_EMAIL": DEFAULT_SUPPORT_EMAIL,
        "REVOCRED_PRIVACY_URL": DEFAULT_PRIVACY_URL,
        "REVOCRED_TERMS_URL": DEFAULT_TERMS_URL,
        "REVOCRED_SUPPORT_URL": DEFAULT_SUPPORT_URL,
    }
    if env_file is not None:
        config.update(parse_env_file(env_file))
    for key in BUILD_DEFINE_KEYS:
        if key in env and env[key] != "":
            config[key] = env[key]
    if auth_redirect_url is not None:
        config["REVOCRED_AUTH_REDIRECT_URL"] = auth_redirect_url
    if production_override is not None:
        config["REVOCRED_PRODUCTION"] = "true" if production_override else "false"
    return config


def validate_pwa_config(config: dict[str, str]) -> None:
    """Validate public PWA build settings without printing secrets."""
    if config.get("REVOCRED_USE_MOCKS") != "false":
        raise ValueError("Hosted PWA builds require REVOCRED_USE_MOCKS=false.")
    if config.get("REVOCRED_PRODUCTION") == "true":
        validate_production_release(config)
        redirect = urlparse(config.get("REVOCRED_AUTH_REDIRECT_URL", ""))
        if redirect.scheme != "https":
            raise ValueError("Web PWA requires an HTTPS REVOCRED_AUTH_REDIRECT_URL.")
        return

    for key in (
        "REVOCRED_API_URL",
        "SUPABASE_URL",
        "REVOCRED_AUTH_REDIRECT_URL",
        "REVOCRED_PRIVACY_URL",
        "REVOCRED_TERMS_URL",
        "REVOCRED_SUPPORT_URL",
    ):
        parsed = urlparse(config.get(key, ""))
        if (
            parsed.scheme != "https"
            or not parsed.hostname
            or parsed.hostname in ("localhost", "127.0.0.1", "::1")
            or parsed.username
            or parsed.fragment
        ):
            raise ValueError(
                f"{key} must be a public HTTPS URL without credentials or fragments."
            )
    validate_public_key(config.get("SUPABASE_ANON_KEY", ""))


def resolve_tool(env_var: str, binary_name: str, fallback: Path | None = None) -> str:
    candidate = os.environ.get(env_var) or shutil.which(binary_name)
    if not candidate and fallback is not None and fallback.is_file():
        candidate = str(fallback)
    if candidate and not Path(candidate).is_file():
        candidate = shutil.which(candidate)
    if not candidate:
        raise ValueError(f"Required tool `{binary_name}` not found on PATH or via {env_var}.")
    return candidate


def flutter_build_command(flutter: str, config: dict[str, str], output_dir: Path) -> list[str]:
    command = [
        flutter,
        "build",
        "web",
        "--release",
        "--no-web-resources-cdn",
        f"--output={output_dir}",
    ]
    for key in BUILD_DEFINE_KEYS:
        command.append(f"--dart-define={key}={config[key]}")
    return command


def stage_vercel_config(output_dir: Path, vercel_config: Path = VERCEL_CONFIG) -> Path:
    if not vercel_config.is_file():
        raise ValueError("Missing revocred_flutter/vercel.json.")
    # Ensure vercel.json is valid JSON before staging.
    try:
        json.loads(vercel_config.read_text(encoding="utf-8"))
    except ValueError:
        raise ValueError("revocred_flutter/vercel.json is not valid JSON.") from None
    destination = output_dir / "vercel.json"
    shutil.copyfile(vercel_config, destination)
    return destination


def vercel_deploy_command(
    vercel: str,
    output_dir: Path,
    *,
    prod: bool,
    project: str,
    scope: str,
    token: str | None = None,
) -> list[str]:
    command = [
        vercel,
        "deploy",
        str(output_dir),
        "--yes",
        "--project",
        project,
    ]
    if scope:
        command.extend(["--scope", scope])
    if prod:
        command.append("--prod")
    if token:
        command.extend(["--token", token])
    return command


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--env-file",
        type=Path,
        default=None,
        help="Optional KEY=VALUE or JSON file with public build defines.",
    )
    parser.add_argument(
        "--auth-redirect-url",
        default=None,
        help="Override REVOCRED_AUTH_REDIRECT_URL (e.g. https://app.revocred.com/).",
    )
    prod_group = parser.add_mutually_exclusive_group()
    prod_group.add_argument(
        "--production",
        dest="production",
        action="store_true",
        default=None,
        help="Set REVOCRED_PRODUCTION=true (requires complete legal defines).",
    )
    prod_group.add_argument(
        "--no-production",
        dest="production",
        action="store_false",
        help="Set REVOCRED_PRODUCTION=false (pre-launch live deploy without legal entity).",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=APP / "build/web",
        help="Output directory for flutter build web (default: revocred_flutter/build/web).",
    )
    parser.add_argument(
        "--project",
        default=os.environ.get("VERCEL_PROJECT_ID") or DEFAULT_VERCEL_PROJECT,
        help="Vercel project name or ID.",
    )
    parser.add_argument(
        "--scope",
        default=os.environ.get("VERCEL_ORG_ID") or DEFAULT_VERCEL_SCOPE,
        help="Vercel team slug or org ID.",
    )
    parser.add_argument(
        "--preview",
        action="store_true",
        help="Deploy a Vercel preview instead of production.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Validate configuration only; do not build or deploy.",
    )
    parser.add_argument(
        "--build-only",
        action="store_true",
        help="Build and stage vercel.json without deploying to Vercel.",
    )
    args = parser.parse_args(argv)

    try:
        config = resolve_build_config(
            env=dict(os.environ),
            env_file=args.env_file,
            auth_redirect_url=args.auth_redirect_url,
            production_override=args.production,
        )
        validate_pwa_config(config)

        dart = resolve_tool(
            "DART",
            "dart",
            Path.home() / ".local/share/flutter/bin/dart",
        )
        validate_env = {**os.environ, **config}
        subprocess.run(
            [dart, "run", "tool/validate_build.dart"],
            cwd=APP,
            env=validate_env,
            check=True,
        )

        if args.check:
            print(
                f"PWA build configuration valid (production={config['REVOCRED_PRODUCTION']}, "
                f"redirect={config['REVOCRED_AUTH_REDIRECT_URL']})."
            )
            return 0

        flutter = resolve_tool(
            "FLUTTER",
            "flutter",
            Path.home() / ".local/share/flutter/bin/flutter",
        )
        output_dir = args.output.resolve()
        subprocess.run(
            flutter_build_command(flutter, config, output_dir),
            cwd=APP,
            check=True,
        )
        stage_vercel_config(output_dir)
        print(f"Built PWA bundle in {output_dir} with vercel.json.")

        if args.build_only:
            return 0

        vercel = resolve_tool("VERCEL", "vercel")
        deploy_cmd = vercel_deploy_command(
            vercel,
            output_dir,
            prod=not args.preview,
            project=args.project,
            scope=args.scope,
            token=os.environ.get("VERCEL_TOKEN") or None,
        )
        subprocess.run(deploy_cmd, cwd=output_dir, check=True)
        return 0
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        if isinstance(error, subprocess.CalledProcessError):
            print("PWA build or deploy command failed; inspect output above.", file=sys.stderr)
        else:
            print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
