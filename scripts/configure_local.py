#!/usr/bin/env python3
"""Create gitignored env files for the running local Supabase stack."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]


# REVO provider settings; AI_* are preferred, OPENCODE_GO_* are the older names.
AI_KEYS = ("AI_API_KEY", "AI_MODEL", "AI_BASE_URL", "AI_REASONING_EFFORT",
           "OPENCODE_GO_API_KEY", "OPENCODE_GO_MODEL", "OPENCODE_GO_BASE_URL")


def main() -> None:
    result = subprocess.run(
        ["supabase", "status", "--output", "json"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    status = json.loads(result.stdout)
    required = ("API_URL", "ANON_KEY", "DB_URL")
    missing = [key for key in required if not status.get(key)]
    if missing:
        raise SystemExit(f"local Supabase status is missing: {', '.join(missing)}")

    frontend = "\n".join(
        (
            "REVOCRED_USE_MOCKS=false",
            "REVOCRED_WEB_PORT=8081",
            "REVOCRED_API_URL=http://127.0.0.1:8082",
            f"SUPABASE_URL={status['API_URL']}",
            f"SUPABASE_ANON_KEY={status['ANON_KEY']}",
            "",
        )
    )
    preserved = {}
    api_path = ROOT / "revocred-api" / ".env.local"
    if api_path.exists():
        for line in api_path.read_text(encoding="utf-8").splitlines():
            if line.split("=", 1)[0] in AI_KEYS:
                key, value = line.split("=", 1)
                preserved[key] = value
    api_lines = [
        "APP_ENV=development",
        "PORT=8082",
        f"DATABASE_URL={status['DB_URL']}",
        f"SUPABASE_URL={status['API_URL']}",
        f"SUPABASE_ANON_KEY={status['ANON_KEY']}",
        "CORS_ALLOWED_ORIGINS=http://localhost:8081,http://127.0.0.1:8081,http://localhost:8083,http://127.0.0.1:8083",
        "REQUEST_TIMEOUT=30s",
        "SHUTDOWN_TIMEOUT=10s",
        "DB_MAX_CONNS=10",
    ]
    for key in AI_KEYS:
        if key in preserved:
            api_lines.append(f"{key}={preserved[key]}")
    api = "\n".join(api_lines) + "\n"
    (ROOT / ".env.local").write_text(frontend, encoding="utf-8")
    (ROOT / "revocred-api" / ".env.local").write_text(api, encoding="utf-8")
    print("Created gitignored local frontend and API env files.")


if __name__ == "__main__":
    main()
