#!/usr/bin/env python3
"""Create gitignored env files for the running local Supabase stack."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]


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
    api = "\n".join(
        (
            "APP_ENV=development",
            "PORT=8082",
            f"DATABASE_URL={status['DB_URL']}",
            f"SUPABASE_URL={status['API_URL']}",
            f"SUPABASE_ANON_KEY={status['ANON_KEY']}",
            "CORS_ALLOWED_ORIGINS=http://localhost:8081,http://127.0.0.1:8081,http://localhost:8083,http://127.0.0.1:8083",
            "REQUEST_TIMEOUT=10s",
            "SHUTDOWN_TIMEOUT=10s",
            "DB_MAX_CONNS=10",
            "",
        )
    )
    (ROOT / ".env.local").write_text(frontend, encoding="utf-8")
    (ROOT / "revocred-api" / ".env.local").write_text(api, encoding="utf-8")
    print("Created gitignored local frontend and API env files.")


if __name__ == "__main__":
    main()
