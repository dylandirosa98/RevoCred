#!/usr/bin/env python3
"""Apply forward migrations to local Supabase and exercise a temporary local API."""
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import urllib.request
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]


def main():
    values = dict(line.split('=', 1) for line in (ROOT / 'revocred-api/.env.local').read_text().splitlines() if line and not line.startswith('#'))
    for key in ('DATABASE_URL', 'SUPABASE_URL'):
        if urlparse(values[key]).hostname not in ('localhost', '127.0.0.1'):
            raise SystemExit('Verification refuses non-loopback services')
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    env = {**os.environ, **values, 'PORT': str(port), 'GOOSE_DRIVER': 'postgres', 'GOOSE_DBSTRING': values['DATABASE_URL']}
    subprocess.run([str(ROOT / 'revocred-api/bin/goose'), '-dir', 'migrations', 'up'], cwd=ROOT / 'revocred-api', env=env, check=True)
    with tempfile.TemporaryDirectory(prefix='revocred-verify-') as directory:
        binary = str(Path(directory) / 'api')
        subprocess.run(['go', 'build', '-o', binary, './cmd/api'], cwd=ROOT / 'revocred-api', check=True)
        with tempfile.TemporaryFile() as logs:
            process = subprocess.Popen([binary], env=env, stdout=logs, stderr=logs)
            try:
                base = f'http://127.0.0.1:{port}'
                for _ in range(50):
                    try:
                        with urllib.request.urlopen(base + '/readyz', timeout=2) as response:
                            if response.status == 200:
                                break
                    except OSError:
                        time.sleep(.2)
                else:
                    raise RuntimeError('Temporary API did not become ready')
                subprocess.run(['python3', 'scripts/local_e2e.py'], cwd=ROOT, env={**os.environ, 'REVOCRED_E2E_API_URL': base}, check=True)
            finally:
                process.terminate()
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                if process.returncode not in (0, -15):
                    logs.seek(0)
                    print(logs.read().decode())


if __name__ == '__main__':
    main()
