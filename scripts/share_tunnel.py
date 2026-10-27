#!/usr/bin/env python3
"""Point the real-data preview at the live share tunnels.

`make local-preview` serves the app on 127.0.0.1 and bakes loopback URLs into
the web bundle. A `cloudflared --url http://127.0.0.1:<port>` quick tunnel
publishes each of those ports, but the running services still believe every
caller is local, so a browser opened through the tunnel is rejected:

  - the API answers 403 `origin_not_allowed` because the tunnel host is not in
    `CORS_ALLOWED_ORIGINS`;
  - the web bundle still calls `http://127.0.0.1:8082`, which resolves to the
    visitor's own machine, not this host;
  - Supabase rejects the password-recovery callback unless the new tunnel host
    is in `additional_redirect_urls`.

This module resolves the public URL of each tunnel and reports exactly what has
to change. It never edits Go or Dart source, and it never loosens the
production rules: only `APP_ENV=development` may publish tunnel origins.

Usage:
    python3 scripts/share_tunnel.py            # report the current wiring
    python3 scripts/share_tunnel.py --apply    # write the gitignored env files
"""
from __future__ import annotations

import argparse
import json
import re
import socket
import sys
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
STATE = ROOT / ".local"
LOG_DIR = Path("/tmp/opencode")

API_PORT = 8082
WEB_PORT = 8083
AUTH_PORT = 54321
REQUIRED_PORTS = (API_PORT, WEB_PORT, AUTH_PORT)

PUBLIC_URL = re.compile(r"https://[a-z0-9-]+\.(?:trycloudflare\.com|ngrok-free\.dev|ngrok\.app)")
TUNNEL_SUFFIXES = ("trycloudflare.com", "ngrok-free.dev", "ngrok.app")
LOOPBACK_URL = re.compile(r"https?://(?:localhost|127\.0\.0\.1)(?::\d+)?")
REDIRECT_LINE = re.compile(r"^additional_redirect_urls\s*=\s*(\[[^\]]*\])", re.MULTILINE)


# REVO provider settings; AI_* are preferred, OPENCODE_GO_* are the older names.
AI_KEYS = ("AI_API_KEY", "AI_MODEL", "AI_BASE_URL", "AI_REASONING_EFFORT",
           "OPENCODE_GO_API_KEY", "OPENCODE_GO_MODEL", "OPENCODE_GO_BASE_URL")


def share_paths() -> dict[str, Path]:
    """Locate the env files this script owns, keeping tunnel config separate.

    `make local-preview` and `make verify-local` both refuse non-loopback values
    in `.env.local`, so the public tunnel URLs live in their own gitignored
    `.env.share*` pair and the loopback files are never touched.
    """
    return {
        "frontend": ROOT / ".env.local",
        "api": ROOT / "revocred-api" / ".env.local",
        "share_frontend": ROOT / ".env.share",
        "share_api": ROOT / "revocred-api" / ".env.share",
    }


def env_file(path: Path) -> dict[str, str]:
    return dict(
        line.split("=", 1)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line and not line.startswith("#") and "=" in line
    )


def write_env_file(path: Path, values: dict[str, str], preserved: tuple[str, ...] = ()) -> None:
    """Rewrite an env file, keeping keys the caller does not own and refreshing owned values."""
    existing = env_file(path) if path.exists() else {}
    merged = dict(existing)
    merged.update(values)
    ordered = [key for key in preserved if key in merged]
    ordered += [key for key in merged if key not in ordered]
    body = [f"{key}={merged[key]}" for key in ordered]
    path.write_text("\n".join(body) + "\n", encoding="utf-8")
    path.chmod(0o600)


def build_share_api(api_env: dict[str, str], app_url: str) -> dict[str, str]:
    """Copy only the API settings the shared process needs, including AI credentials."""
    required = ("APP_ENV", "PORT", "DATABASE_URL", "SUPABASE_URL", "SUPABASE_ANON_KEY",
                "REQUEST_TIMEOUT", "SHUTDOWN_TIMEOUT", "DB_MAX_CONNS")
    missing = [key for key in required if not api_env.get(key)]
    if missing:
        raise ValueError("local API configuration is missing: " + ", ".join(missing))
    shared = {key: api_env[key] for key in required}
    shared["CORS_ALLOWED_ORIGINS"] = build_api_origins(api_env.get("CORS_ALLOWED_ORIGINS", ""), app_url)
    for key in AI_KEYS:
        if api_env.get(key):
            shared[key] = api_env[key]
    return shared


def discover_tunnels(logs: dict[int, str]) -> dict[int, str]:
    """Map each local port to the public URL its tunnel is serving."""
    found: dict[int, str] = {}
    for port, text in logs.items():
        matches = PUBLIC_URL.findall(text or "")
        if matches:
            found[port] = matches[-1].rstrip("/")
    return found


def read_tunnel_logs() -> dict[int, str]:
    """Read the tunnel log belonging to each port this stack needs."""
    logs: dict[int, str] = {}
    for path in sorted(LOG_DIR.glob(f"tunnel-*.log")):
        port = path.stem.split("-")[-1]
        if port.isdigit():
            logs[int(port)] = path.read_text(encoding="utf-8", errors="replace")
    return logs


def is_listening(port: int, host: str = "127.0.0.1") -> bool:
    with socket.socket() as sock:
        sock.settimeout(1)
        return sock.connect_ex((host, port)) == 0


def build_share_defines(frontend: dict[str, str], tunnels: dict[int, str]) -> dict[str, str]:
    """Return the dart-define values a browser reached through the tunnels needs."""
    missing = [port for port in REQUIRED_PORTS if port not in tunnels]
    if missing:
        raise ValueError(
            "no public tunnel URL for port(s) "
            + ", ".join(str(port) for port in missing)
            + "; a quick tunnel may not be running yet"
        )
    for port, url in tunnels.items():
        parsed = urlparse(url)
        if parsed.scheme != "https" or not parsed.hostname or parsed.path:
            raise ValueError(f"tunnel for port {port} is not a bare HTTPS origin: {url}")
    app = tunnels[WEB_PORT]
    defines = {
        "REVOCRED_USE_MOCKS": frontend["REVOCRED_USE_MOCKS"],
        "REVOCRED_API_URL": tunnels[API_PORT],
        "SUPABASE_URL": tunnels[AUTH_PORT],
        "SUPABASE_ANON_KEY": frontend["SUPABASE_ANON_KEY"],
        "REVOCRED_AUTH_REDIRECT_URL": app,
    }
    return defines


def build_api_origins(existing: str, app_url: str) -> str:
    """Add the tunnel web origin to CORS_ALLOWED_ORIGINS, dropping dead tunnels."""
    app_url = (app_url or "").strip().rstrip("/")
    parsed = urlparse(app_url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.path or parsed.username:
        raise ValueError("refusing to add a non-HTTPS or credentialed origin to CORS_ALLOWED_ORIGINS")
    if parsed.hostname in ("localhost", "127.0.0.1", "::1"):
        raise ValueError("refusing to add a loopback origin to CORS_ALLOWED_ORIGINS")
    kept: list[str] = []
    for origin in (item.strip().rstrip("/") for item in existing.split(",")):
        if not origin:
            continue
        if origin == "*":
            raise ValueError("CORS_ALLOWED_ORIGINS must not contain a wildcard")
        host = urlparse(origin).hostname or ""
        if host.endswith(TUNNEL_SUFFIXES) and host != parsed.hostname:
            continue  # a rotated quick tunnel: dropping it keeps the list truthful
        if origin not in kept:
            kept.append(origin)
    if app_url not in kept:
        kept.append(app_url)
    return ",".join(kept)


def find_loopback_endpoints(bundle: str) -> list[str]:
    """Return the loopback URLs still baked into a built web bundle."""
    return sorted(set(LOOPBACK_URL.findall(bundle or "")))


def missing_redirect_allowances(config: str, app_url: str) -> list[str]:
    """Return the tunnel origin Supabase does not yet accept as a callback."""
    match = REDIRECT_LINE.search(config or "")
    if not match:
        return [app_url]
    if app_url in match.group(1):
        return []
    return [app_url]


def rewrite_redirect_allowances(config: str, app_url: str) -> str:
    """Add the tunnel origin to additional_redirect_urls, preserving the rest."""
    entry = f'"{app_url}/**"'
    match = REDIRECT_LINE.search(config or "")
    if not match:
        raise ValueError("supabase/config.toml has no additional_redirect_urls line to update")
    if entry in match.group(1):
        return config
    updated = match.group(1)[:-1].rstrip().rstrip(",") + ", " + entry + "]"
    return config[: match.start(1)] + updated + config[match.end(1) :]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="write the gitignored .env.share pair and allow the tunnel origin",
    )
    arguments = parser.parse_args()

    tunnels = discover_tunnels(read_tunnel_logs())
    if not tunnels:
        print("No tunnel logs found under /tmp/opencode/tunnel-*.log; start one with:")
        print(f"  cloudflared tunnel --no-autoupdate --url http://127.0.0.1:{API_PORT}")
        return 1

    paths = share_paths()
    if not paths["api"].exists() or not paths["frontend"].exists():
        print("Local env files are missing; run make local-setup first.")
        return 1
    api_env = env_file(paths["api"])
    frontend = env_file(paths["frontend"])
    if api_env.get("APP_ENV") == "production":
        print("Refusing to publish tunnel origins in a production environment.")
        return 1

    print("Tunnels in use:")
    for port in REQUIRED_PORTS:
        url = tunnels.get(port)
        state = "up" if url and is_listening(port) else ("no public URL" if not url else "origin down")
        print(f"  {port}: {url or '-'} ({state})")

    defines = build_share_defines(frontend, tunnels)
    # The allow list stays in the loopback file: the API reads CORS_ALLOWED_ORIGINS
    # from it, and the local gates only object to non-loopback service URLs.
    origins = build_api_origins(api_env.get("CORS_ALLOWED_ORIGINS", ""), defines["REVOCRED_AUTH_REDIRECT_URL"])
    config_path = ROOT / "supabase" / "config.toml"
    config = config_path.read_text(encoding="utf-8") if config_path.exists() else ""
    missing = missing_redirect_allowances(config, defines["REVOCRED_AUTH_REDIRECT_URL"])

    print(f"\nWeb build should call: {defines['REVOCRED_API_URL']}")
    print(f"Auth should use:      {defines['SUPABASE_URL']}")
    print(f"Auth callback:        {defines['REVOCRED_AUTH_REDIRECT_URL']}")
    print(f"CORS origins should be:\n  {origins}")
    if missing:
        print(f"Supabase still needs: {', '.join(missing)} in additional_redirect_urls")

    if not arguments.apply:
        print("\nRe-run with --apply to write the gitignored tunnel env files.")
        return 0

    write_env_file(
        paths["share_frontend"],
        {
            "REVOCRED_USE_MOCKS": defines["REVOCRED_USE_MOCKS"],
            "REVOCRED_API_URL": defines["REVOCRED_API_URL"],
            "SUPABASE_URL": defines["SUPABASE_URL"],
            "SUPABASE_ANON_KEY": defines["SUPABASE_ANON_KEY"],
            "REVOCRED_AUTH_REDIRECT_URL": defines["REVOCRED_AUTH_REDIRECT_URL"],
        },
    )
    write_env_file(paths["share_api"], build_share_api(api_env, defines["REVOCRED_AUTH_REDIRECT_URL"]))
    if missing:
        config_path.write_text(rewrite_redirect_allowances(config, defines["REVOCRED_AUTH_REDIRECT_URL"]), encoding="utf-8")
        print(f"Allowed {', '.join(missing)} as an auth callback in supabase/config.toml")
        print("  supabase stop && supabase start   # required before recovery links work")
    print("\nWrote .env.share and revocred-api/.env.share. Rebuild the shared build with:")
    print("  make share-preview")
    return 0


if __name__ == "__main__":
    sys.exit(main())
