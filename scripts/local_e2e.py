#!/usr/bin/env python3
"""Exercise the local Supabase -> Go API product flow."""

from __future__ import annotations

import json
from pathlib import Path
import time
from typing import Any
import urllib.request


ROOT = Path(__file__).resolve().parents[1]


def load_env(path: Path) -> dict[str, str]:
    return dict(
        line.split("=", 1)
        for line in path.read_text(encoding="utf-8").splitlines()
        if line and not line.startswith("#")
    )


def request(
    url: str,
    method: str = "GET",
    body: dict[str, object] | None = None,
    headers: dict[str, str] | None = None,
) -> tuple[int, Any]:
    encoded = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(url, data=encoded, method=method, headers=headers or {})
    if encoded is not None:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=15) as response:
        payload = response.read()
        return response.status, json.loads(payload) if payload else {}


def main() -> None:
    config = load_env(ROOT / ".env.local")
    email = f"e2e-{time.time_ns()}@example.test"
    _, signup = request(
        f"{config['SUPABASE_URL']}/auth/v1/signup",
        "POST",
        {"email": email, "password": "LocalTest-Only-4837!"},
        {"apikey": config["SUPABASE_ANON_KEY"]},
    )
    token = signup.get("access_token")
    if not isinstance(token, str) or not token:
        raise AssertionError("local signup did not return an access token")
    headers = {"Authorization": f"Bearer {token}"}
    api = config["REVOCRED_API_URL"]

    _, bootstrap = request(f"{api}/v1/bootstrap", headers=headers)
    catalog = bootstrap["data"]["catalog"]
    if len(catalog) != 6:
        raise AssertionError(f"expected 6 demo cards, got {len(catalog)}")

    status, wallet = request(
        f"{api}/v1/wallet",
        "POST",
        {"catalog_card_id": catalog[0]["id"], "nickname": "", "status": "active"},
        headers,
    )
    if status != 201:
        raise AssertionError(f"wallet create returned {status}")

    status, recommendation = request(
        f"{api}/v1/recommendations",
        "POST",
        {
            "monthly_category_spend": {
                "rent": 120000,
                "food": 60000,
                "travel": 20000,
                "everyday": 40000,
            },
            "fee_tolerance_cents": 10000,
            "travel_scope": "both",
            "rewards_goal": "travel",
            "credit_tier": "good",
            "existing_card_ids": [],
        },
        headers,
    )
    if status != 201 or not recommendation["data"]["items"]:
        raise AssertionError("recommendation did not return ranked cards")

    _, refreshed = request(f"{api}/v1/bootstrap", headers=headers)
    data = refreshed["data"]
    if data["latest_questionnaire"]["monthly_category_spend"]["food"] != 60000:
        raise AssertionError("questionnaire spend was not restored")
    if data["wallet_metrics"]["score"] < 22:
        raise AssertionError("wallet score was not computed")
    if not data["profile"]["next_application_target"]:
        raise AssertionError("profile target was not updated")

    status, chat = request(
        f"{api}/v1/chat/messages",
        "POST",
        {"content": "What should I apply for next?"},
        headers,
    )
    if status != 201 or len(chat["data"]) != 2:
        raise AssertionError("chat exchange was not persisted")

    status, _ = request(
        f"{api}/v1/wallet",
        "DELETE",
        {"wallet_card_id": wallet["data"]["id"]},
        headers,
    )
    if status != 204:
        raise AssertionError(f"wallet delete returned {status}")

    print("Local E2E passed: auth, catalog, wallet, recommendation, metrics, profile, chat.")


if __name__ == "__main__":
    main()
