#!/usr/bin/env python3
"""Build and serve the real-data preview through the live share tunnels.

Same local services as `make local-preview`, but the web bundle is compiled
with the public tunnel URLs (written by `scripts/share_tunnel.py --apply`) so a
browser reached through Cloudflare calls this host's API instead of the
visitor's own 127.0.0.1.

The loopback `.env.local` files are never modified, so `make local-preview` and
`make verify-local` keep working unchanged.
"""
from __future__ import annotations

import json
import os
import signal
import socket
import subprocess
import sys
import time
import urllib.request
from pathlib import Path
from urllib.parse import urlparse

sys.path.insert(0, str(Path(__file__).resolve().parent))
from share_tunnel import (  # noqa: E402
    API_PORT,
    AUTH_PORT,
    WEB_PORT,
    discover_tunnels,
    env_file,
    read_tunnel_logs,
    share_paths,
)

ROOT = Path(__file__).resolve().parents[1]
STATE = ROOT / ".local"
RECORD = STATE / "share-processes.json"


def stop() -> None:
    if not RECORD.exists():
        return
    for entry in json.loads(RECORD.read_text(encoding="utf-8")):
        try:
            command = Path(f"/proc/{entry['pid']}/cmdline").read_bytes().replace(b"\0", b" ").decode()
            if str(STATE) in command:
                os.killpg(entry["pid"], signal.SIGTERM)
        except (ProcessLookupError, FileNotFoundError):
            pass
    RECORD.unlink()


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "stop":
        stop()
        print("Stopped shared preview processes.")
        return 0

    paths = share_paths()
    tunnels = discover_tunnels(read_tunnel_logs())
    for key, label in (("share_frontend", ".env.share"), ("share_api", "revocred-api/.env.share")):
        if not paths[key].exists():
            print(f"{label} is missing; run: python3 scripts/share_tunnel.py --apply")
            return 1
    frontend = env_file(paths["share_frontend"])
    api = env_file(paths["share_api"])
    if api.get("APP_ENV") == "production":
        print("Refusing to publish a production build through a quick tunnel.")
        return 1
    if frontend["REVOCRED_USE_MOCKS"] != "false":
        print("The shared preview must run in real mode (REVOCRED_USE_MOCKS=false).")
        return 1
    for value in (frontend["REVOCRED_API_URL"], frontend["SUPABASE_URL"], frontend["REVOCRED_AUTH_REDIRECT_URL"]):
        parsed = urlparse(value)
        if parsed.scheme != "https" or parsed.hostname in ("localhost", "127.0.0.1", "::1"):
            print(f"Shared build endpoint is not a public HTTPS origin: {value}")
            return 1

    for port in (API_PORT, WEB_PORT, AUTH_PORT):
        if port not in tunnels:
            print(
                f"No public tunnel is publishing port {port}; start it with:\n"
                f"  cloudflared tunnel --no-autoupdate --url http://127.0.0.1:{port} "
                f"> /tmp/opencode/tunnel-{port}.log 2>&1 &"
            )
            return 1

    stop()
    STATE.mkdir(exist_ok=True)
    binary = STATE / "revocred-api.share"
    subprocess.run(["go", "build", "-o", str(binary), "./cmd/api"], cwd=ROOT / "revocred-api", check=True)
    flutter = os.environ.get("FLUTTER", str(Path.home() / ".local/share/flutter/bin/flutter"))
    subprocess.run(
        [
            flutter, "build", "web", "--release", "--no-web-resources-cdn",
            f"--dart-define-from-file=../{paths['share_frontend'].name}",
            "--output=" + str(STATE / "share-web"),
        ],
        cwd=ROOT / "revocred_flutter",
        check=True,
    )

    entries = []
    try:
        for name, command, environment in (
            ("api", [str(binary)], {**os.environ, **api, "PORT": str(API_PORT)}),
            ("web", [sys.executable, "-m", "http.server", str(WEB_PORT), "--bind", "127.0.0.1",
                     "--directory", str(STATE / "share-web")], os.environ),
        ):
            with (STATE / f"share-{name}.log").open("ab") as log:
                process = subprocess.Popen(command, env=environment, stdout=log, stderr=log, start_new_session=True)
            entries.append({"name": name, "pid": process.pid})
        RECORD.write_text(json.dumps(entries), encoding="utf-8")
        for _ in range(50):
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{API_PORT}/readyz", timeout=2) as response:
                    if response.status == 200:
                        print(f"Shared preview: {frontend['REVOCRED_AUTH_REDIRECT_URL']} | logs: .local/share-*.log")
                        return 0
            except OSError:
                time.sleep(.2)
        raise RuntimeError("API startup failed; inspect .local/share-api.log")
    except BaseException:
        stop()
        raise


if __name__ == "__main__":
    sys.exit(main())
