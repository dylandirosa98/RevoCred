#!/usr/bin/env python3
"""Exercise the local Supabase -> Go API product flow."""

from __future__ import annotations

import json
import os
from pathlib import Path
import time
from typing import Any
import urllib.request
import urllib.parse


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
    config['REVOCRED_API_URL'] = os.environ.get('REVOCRED_E2E_API_URL', config['REVOCRED_API_URL'])
    for key in ('SUPABASE_URL', 'REVOCRED_API_URL'):
        if urllib.parse.urlparse(config[key]).hostname not in ('127.0.0.1', 'localhost'):
            raise SystemExit('Local E2E refuses non-loopback services')
    email = f"e2e-{time.time_ns()}@example.test"
    _, signup = request(
        f"{config['SUPABASE_URL']}/auth/v1/signup",
        "POST",
        {"email": email, "password": "LocalTest-Only-4837!"},
        {"apikey": config["SUPABASE_ANON_KEY"]},
    )
    _, login = request(f"{config['SUPABASE_URL']}/auth/v1/token?grant_type=password", "POST",
        {"email": email, "password": "LocalTest-Only-4837!"}, {"apikey": config['SUPABASE_ANON_KEY']})
    token = login.get("access_token")
    if not isinstance(token, str) or not token:
        raise AssertionError("local signup did not return an access token")
    headers = {"Authorization": f"Bearer {token}"}
    api = config["REVOCRED_API_URL"]

    try:
        run_flow(api, headers)
    finally:
        status, _ = request(f"{api}/v1/account", "DELETE", headers=headers)
        if status != 204:
            raise AssertionError('test-account cleanup failed')


def run_flow(api, headers):

    _, bootstrap = request(f"{api}/v1/bootstrap", headers=headers)
    catalog = bootstrap["data"]["catalog"]
    if len(catalog) < 14:
        raise AssertionError(f"expected at least 14 catalog cards, got {len(catalog)}")
    if any('Demo' in card['name'] for card in catalog):
        raise AssertionError('demo card leaked into live catalog')

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
    if recommendation["data"]["strategy_code"] != "S04":
        raise AssertionError("recommendation did not select the expected strategy")

    _, refreshed = request(f"{api}/v1/bootstrap", headers=headers)
    data = refreshed["data"]
    if data["latest_questionnaire"]["monthly_category_spend"]["food"] != 60000:
        raise AssertionError("questionnaire spend was not restored")
    if data["wallet_metrics"]["score"] < 22:
        raise AssertionError("wallet score was not computed")
    if not data["profile"]["next_application_target"]:
        raise AssertionError("profile target was not updated")
    if data["profile"]["credit_card_strategy"] != "S04":
        raise AssertionError("strategy was not saved to the profile")
    if data["latest_recommendations"]["strategy_code"] != "S04":
        raise AssertionError("strategy was not restored with the recommendation")

    status, chat = request(
        f"{api}/v1/chat/messages",
        "POST",
        {"content": "What should I apply for next?"},
        headers,
    )
    if status != 201 or len(chat["data"]) != 2:
        raise AssertionError("chat exchange was not persisted")

    _, export = request(f"{api}/v1/account/export", headers=headers)
    if not export['data']['records']['recommendation_runs']:
        raise AssertionError('account export omitted recommendation history')

    status, _ = request(
        f"{api}/v1/wallet",
        "DELETE",
        {"wallet_card_id": wallet["data"]["id"]},
        headers,
    )
    if status != 204:
        raise AssertionError(f"wallet delete returned {status}")

    print(
        "Local E2E passed: auth, catalog, wallet, strategy, recommendation, "
        "metrics, profile, chat, account export (test account deleted on exit)."
    )


if __name__ == "__main__":
    main()
