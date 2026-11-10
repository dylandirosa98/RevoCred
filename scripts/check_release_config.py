#!/usr/bin/env python3
"""Validate public build configuration without printing keys or contacting services."""
import base64
import json
import os
from urllib.parse import urlparse

# Native builds return auth emails to the app's registered deep link
# (AndroidManifest.xml / Info.plist), not to a hosted web page.
MOBILE_AUTH_CALLBACK = "com.revocred.app://auth-callback/"


def validate(env):
    if env.get("REVOCRED_USE_MOCKS") != "false" or env.get("REVOCRED_PRODUCTION") != "true":
        raise ValueError("Release requires REVOCRED_USE_MOCKS=false and REVOCRED_PRODUCTION=true")
    for key in ("REVOCRED_LEGAL_ENTITY", "REVOCRED_SUPPORT_EMAIL", "REVOCRED_LEGAL_JURISDICTION", "REVOCRED_LEGAL_EFFECTIVE_DATE"):
        if not env.get(key, "").strip():
            raise ValueError(key + " is required")
        if "{{" in env[key] or "}}" in env[key]:
            raise ValueError(key + " still contains a template placeholder")
    for key in ("REVOCRED_PRIVACY_URL", "REVOCRED_TERMS_URL", "REVOCRED_API_URL", "SUPABASE_URL", "REVOCRED_AUTH_REDIRECT_URL"):
        if key == "REVOCRED_AUTH_REDIRECT_URL" and env.get(key) == MOBILE_AUTH_CALLBACK:
            continue
        value = urlparse(env.get(key, ""))
        if value.scheme != "https" or not value.hostname or value.hostname in ("localhost", "127.0.0.1", "::1") or value.username or value.fragment:
            raise ValueError(key + " must be a public HTTPS URL without credentials or fragments")
        if key in ("REVOCRED_PRIVACY_URL", "REVOCRED_TERMS_URL") and (value.hostname == "example.com" or value.hostname.endswith(".example.com")):
            raise ValueError(key + " must point at the hosted policy, not the example placeholder")
    validate_public_key(env.get("SUPABASE_ANON_KEY", ""))


def validate_public_key(key):
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
