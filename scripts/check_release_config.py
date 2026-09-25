#!/usr/bin/env python3
"""Validate public build configuration without printing keys or contacting services."""
import base64
import json
import os
from urllib.parse import urlparse


def validate(env):
    if env.get("REVOCRED_USE_MOCKS") != "false" or env.get("REVOCRED_PRODUCTION") != "true":
        raise ValueError("Release requires REVOCRED_USE_MOCKS=false and REVOCRED_PRODUCTION=true")
    for key in ("REVOCRED_API_URL", "SUPABASE_URL", "REVOCRED_AUTH_REDIRECT_URL"):
        value = urlparse(env.get(key, ""))
        if value.scheme != "https" or not value.hostname or value.hostname in ("localhost", "127.0.0.1", "::1") or value.username or value.fragment:
            raise ValueError(key + " must be a public HTTPS URL without credentials or fragments")
    key = env.get("SUPABASE_ANON_KEY", "")
    if key.startswith("sb_publishable_") and len(key) > 20:
        return
    try:
        payload = key.split(".")[1]
        role = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))["role"]
    except (ValueError, IndexError, KeyError):
        raise ValueError("Use a public Supabase publishable or anon key") from None
    if role != "anon":
        raise ValueError("Only an anon/public key may be embedded in the client")


if __name__ == "__main__":
    try:
        validate(os.environ)
    except ValueError as error:
        raise SystemExit(str(error))
    print("Public release configuration passed. Hosted services still require staging verification.")
